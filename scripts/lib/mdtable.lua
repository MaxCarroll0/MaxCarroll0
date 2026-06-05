-- scripts/lib/mdtable.lua: reflow GitHub pipe tables so the raw Markdown columns line up (width by codepoint)

local util = require("lib.util")

local mdtable = {}

local dwidth = util.dwidth

-- '|' and '\' are ASCII, so scanning bytes never splits a multibyte glyph
local function split_cells(line)
  local s = line:gsub("^%s*|", ""):gsub("|%s*$", "")
  local cells, buf, i = {}, {}, 1
  while i <= #s do
    local c = s:sub(i, i)
    if c == "\\" and s:sub(i + 1, i + 1) == "|" then
      buf[#buf + 1] = "|"
      i = i + 2
    elseif c == "|" then
      cells[#cells + 1] = table.concat(buf)
      buf = {}
      i = i + 1
    else
      buf[#buf + 1] = c
      i = i + 1
    end
  end
  cells[#cells + 1] = table.concat(buf)
  for k, v in ipairs(cells) do
    cells[k] = (v:gsub("^%s+", ""):gsub("%s+$", ""))
  end
  return cells
end

local function is_delim(line)
  if not line or not line:find("|") then
    return false
  end
  local cells = split_cells(line)
  if #cells == 0 then
    return false
  end
  for _, c in ipairs(cells) do
    if not c:match("^:?%-+:?$") then
      return false
    end
  end
  return true
end

local function align_of(cell)
  local l, r = cell:sub(1, 1) == ":", cell:sub(-1) == ":"
  if l and r then
    return "c"
  elseif r then
    return "r"
  elseif l then
    return "l"
  end
  return "d"
end

local function pad(s, w, a)
  local d = w - dwidth(s)
  if d <= 0 then
    return s
  end
  if a == "r" then
    return string.rep(" ", d) .. s
  end
  if a == "c" then
    local left = d // 2
    return string.rep(" ", left) .. s .. string.rep(" ", d - left)
  end
  return s .. string.rep(" ", d)
end

local function format_block(block)
  local rows = {}
  for _, ln in ipairs(block) do
    rows[#rows + 1] = split_cells(ln)
  end
  local ncol = #rows[1]

  local aligns, widths = {}, {}
  for c = 1, ncol do
    aligns[c] = align_of(rows[2][c] or "-")
    widths[c] = 3
  end
  for r, cells in ipairs(rows) do
    if r ~= 2 then
      for c = 1, ncol do
        local w = dwidth(cells[c] or "")
        if w > widths[c] then
          widths[c] = w
        end
      end
    end
  end

  local out = {}
  for r, cells in ipairs(rows) do
    local parts = {}
    for c = 1, ncol do
      if r == 2 then
        local w, a = widths[c], aligns[c]
        if a == "c" then
          parts[c] = ":" .. string.rep("-", math.max(1, w - 2)) .. ":"
        elseif a == "r" then
          parts[c] = string.rep("-", math.max(1, w - 1)) .. ":"
        elseif a == "l" then
          parts[c] = ":" .. string.rep("-", math.max(1, w - 1))
        else
          parts[c] = string.rep("-", w)
        end
      else
        parts[c] = pad(cells[c] or "", widths[c], aligns[c])
      end
    end
    out[#out + 1] = "| " .. table.concat(parts, " | ") .. " |"
  end
  return out
end

function mdtable.reflow(text)
  local lines = {}
  for ln in (text .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = ln
  end

  local out, i, n = {}, 1, #lines
  while i <= n do
    if lines[i]:find("|") and is_delim(lines[i + 1]) then
      local block = { lines[i], lines[i + 1] }
      local j = i + 2
      while j <= n and lines[j]:find("|") and not is_delim(lines[j]) do
        block[#block + 1] = lines[j]
        j = j + 1
      end
      for _, fl in ipairs(format_block(block)) do
        out[#out + 1] = fl
      end
      i = j
    else
      out[#out + 1] = lines[i]
      i = i + 1
    end
  end
  return table.concat(out, "\n")
end

return mdtable
