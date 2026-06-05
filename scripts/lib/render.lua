-- scripts/lib/render.lua: render the totals table and the grouped, colour-barred language tables

local util = require("lib.util")
local mdtable = require("lib.mdtable")
local svg = require("lib.svg")
local langgroups = require("lib.langgroups")

local render = {}

local GROUP_ACCENT = {
  ["Programming"] = "#3572A5",
  ["Prose"] = "#1a7f37",
  ["Configs / Data"] = "#9a6700",
}

local function slug(s)
  return (s:lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))
end

-- Non-collapsing space (GitHub eats ASCII runs); inside <code> it is one monospace cell, so columns line up.
local NBSP = "&nbsp;"
local GREY = "#8b949e"

local function home_url(lang, urls, overrides)
  if overrides and overrides[lang] then
    return overrides[lang]
  end
  if not urls then
    return nil
  end
  local base = lang:match("^([^/]+)/") -- "OCaml/Reason" -> "OCaml"
  return urls[util.normkey(lang)] or (base and urls[util.normkey(base)])
end

-- Right-align `s` to `width` monospace cells with leading non-collapsing spaces.
local function code_pad(s, width)
  return ("<code>%s%s</code>"):format(string.rep(NBSP, width - #s), s)
end

local function repo_link(label)
  local owner, repo = label:match("^([^/]+)/([^/]+)$")
  if owner then
    return ('<a href="https://github.com/%s/%s">%s</a>'):format(owner, repo, util.esc(label))
  end
  return util.esc(label)
end

-- Per-project dropdown body: uncoloured (grey) bars filled to each project's share of the language total.
local function breakdown_html(bd, dir, files, bar_w)
  local out = { "<table>" }
  for _, p in ipairs(bd.rows) do
    local bar, fill = svg.rowbar(p.pct / 100, GREY, bar_w, 12)
    local path = ("%s/bar/%s-%d.svg"):format(dir, (GREY:gsub("#", "")), fill)
    files[path] = bar
    local label = repo_link(p.label)
    if p.private then
      label = util.esc(p.label) .. ((p.repos and p.repos > 1) and (" (%d)"):format(p.repos) or "")
    end
    out[#out + 1] = ('<tr><td>%s</td><td align="right">%s</td><td><img src="%s" height="11"> %.1f%%</td></tr>'):format(
      label,
      util.commas(p.lines),
      path,
      p.pct
    )
  end
  out[#out + 1] = "</table>"
  return table.concat(out, "\n")
end

-- Returns { html = <2-column HTML block>, files = { path = svg } } for one metric's grouped result.
function render.metric(result, opts)
  local dir, metric = opts.dir or "assets", opts.metric
  local col_w, bar_w = opts.col_width or 280, opts.bar_width or 90
  local breakdown, urls, overrides = opts.breakdown or {}, opts.urls, opts.url_overrides
  local files, content = {}, {}

  for _, g in ipairs(result.groups) do
    local name_w, count_w, pct_w = 0, 0, 0
    local fmt = {}
    for i, r in ipairs(g.rows) do
      fmt[i] = { cnt = util.commas(r.lines), pct = ("%.1f%%"):format(r.pct) }
      name_w = math.max(name_w, util.dwidth(r.lang))
      count_w = math.max(count_w, #fmt[i].cnt)
      pct_w = math.max(pct_w, #fmt[i].pct)
    end

    local segs, blocks = {}, {}
    for i, r in ipairs(g.rows) do
      local color = r.other and GREY or langgroups.color(r.lang)
      segs[#segs + 1] = { frac = g.total > 0 and r.lines / g.total or 0, color = color }
      local bar, fill = svg.rowbar(r.pct / 100, color, bar_w, 12)
      local bar_path = ("%s/bar/%s-%d.svg"):format(dir, (color:gsub("#", "")), fill)
      files[bar_path] = bar
      local dot_path = ("%s/dot/%s.svg"):format(dir, (color:gsub("#", "")))
      files[dot_path] = svg.dot(color)

      -- link wraps only the language text (inside <code>); padding follows, so the underline stops at the name.
      local url = not r.other and home_url(r.lang, urls, overrides)
      local text = url and ('<a href="%s">%s</a>'):format(util.esc(url), util.esc(r.lang)) or util.esc(r.lang)
      local name = ('<img src="%s" width="10" height="10"> <code>%s%s</code>'):format(
        dot_path,
        text,
        string.rep(NBSP, name_w - util.dwidth(r.lang))
      )
      local summary = ('%s%s%s<img src="%s" height="11">%s%s'):format(
        name,
        code_pad(fmt[i].cnt, 2 + count_w),
        NBSP,
        bar_path,
        NBSP,
        code_pad(fmt[i].pct, pct_w)
      )

      local bd = not r.other and breakdown[r.lang]
      if bd and #bd.rows > 0 then
        blocks[#blocks + 1] = ("<details><summary>%s</summary>\n%s</details>"):format(
          summary,
          breakdown_html(bd, dir, files, bar_w)
        )
      else
        blocks[#blocks + 1] = summary .. "<br>"
      end
    end

    local stack_path = ("%s/stack/%s-%s.svg"):format(dir, metric, slug(g.name))
    files[stack_path] = svg.stacked(g.name, GROUP_ACCENT[g.name] or "#808080", segs, col_w)
    content[g.name] = ('<img src="%s" alt="%s">\n\n%s'):format(stack_path, g.name, table.concat(blocks, "\n"))
  end

  if #result.groups == 0 then
    return { html = "_no data_", files = files }
  end

  -- Arrange classes into columns; classes sharing a column stack vertically.
  local placed, columns = {}, {}
  for _, col in ipairs(opts.columns or {}) do
    local parts = {}
    for _, name in ipairs(col) do
      if content[name] then
        parts[#parts + 1] = content[name]
        placed[name] = true
      end
    end
    if #parts > 0 then
      columns[#columns + 1] = parts
    end
  end
  for _, g in ipairs(result.groups) do
    if not placed[g.name] then
      columns[#columns + 1] = { content[g.name] }
    end
  end

  local cells = {}
  for _, parts in ipairs(columns) do
    cells[#cells + 1] = '<td valign="top">\n\n' .. table.concat(parts, "\n\n") .. "\n\n</td>"
  end
  return { html = "<table>\n<tr>\n" .. table.concat(cells, "\n") .. "\n</tr>\n</table>", files = files }
end

function render.totals(s)
  local rows = {
    "| Metric | Value |",
    "|:--|--:|",
    ("| Languages | %s |"):format(util.commas(s.languages)),
    ("| Lines (all-time) | %s |"):format(util.commas(s.lines)),
    ("| Added (%dd) | %s |"):format(s.days, util.commas(s.added)),
    ("| Repositories | %s |"):format(util.commas(s.repos)),
  }
  return mdtable.reflow(table.concat(rows, "\n"))
end

return render
