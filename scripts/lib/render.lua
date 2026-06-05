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

-- Returns { html = <3-column HTML block>, files = { path = svg } } for one metric's grouped result.
function render.metric(result, opts)
  local dir, metric = opts.dir or "assets", opts.metric
  local col_w, bar_w = opts.col_width or 280, opts.bar_width or 90
  local files, content, order = {}, {}, {}

  for _, g in ipairs(result.groups) do
    local segs = {}
    local rows = { "| Language | Lines | Share |", "|:--|--:|:--|" }
    for _, r in ipairs(g.rows) do
      local color = langgroups.color(r.lang)
      segs[#segs + 1] = { frac = g.total > 0 and r.lines / g.total or 0, color = color }
      local bar, fill = svg.rowbar(r.pct / 100, color, bar_w, 12)
      local bar_path = ("%s/bar/%s-%d.svg"):format(dir, (color:gsub("#", "")), fill)
      files[bar_path] = bar
      rows[#rows + 1] = ('| %s | %s | <img src="%s" height="11"> %.1f%% |'):format(
        r.lang,
        util.commas(r.lines),
        bar_path,
        r.pct
      )
    end

    local stack_path = ("%s/stack/%s-%s.svg"):format(dir, metric, slug(g.name))
    files[stack_path] = svg.stacked(g.name, GROUP_ACCENT[g.name] or "#808080", segs, col_w)
    content[g.name] = ('<img src="%s" alt="%s">\n\n%s'):format(
      stack_path,
      g.name,
      mdtable.reflow(table.concat(rows, "\n"))
    )
    order[#order + 1] = g.name
  end

  if #order == 0 then
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
  for _, name in ipairs(order) do
    if not placed[name] then
      columns[#columns + 1] = { content[name] }
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
