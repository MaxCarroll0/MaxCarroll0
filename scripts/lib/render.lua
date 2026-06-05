-- scripts/lib/render.lua: render grouped language results and a totals table as aligned Markdown

local util = require("lib.util")
local mdtable = require("lib.mdtable")

local render = {}

-- Bar scaled to the group's leader (frac in 0..1); the % column carries the share within its respective language class (e.g. programming langs)
local function bar(frac, width)
  local filled = math.floor(frac * width + 0.5)
  filled = math.max(0, math.min(width, filled))
  return string.rep("█", filled) .. string.rep("░", width - filled)
end

function render.grouped(result, opts)
  local width = opts.bar_length or 12
  local out = { ("| Language | %s | Share |"):format(opts.value_header or "Lines"), "|:--|--:|:--|" }
  for _, g in ipairs(result.groups) do
    out[#out + 1] = ("| **%s** | **%s** | |"):format(g.name, util.commas(g.total))
    local maxv = 0
    for _, r in ipairs(g.rows) do
      if r.lines > maxv then
        maxv = r.lines
      end
    end
    for _, r in ipairs(g.rows) do
      out[#out + 1] = ("| %s | %s | `%s` %.1f%% |"):format(
        r.lang,
        util.commas(r.lines),
        bar(maxv > 0 and r.lines / maxv or 0, width),
        r.pct
      )
    end
  end
  if #result.groups == 0 then
    out[#out + 1] = "| _no data_ | | |"
  end
  return mdtable.reflow(table.concat(out, "\n"))
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
