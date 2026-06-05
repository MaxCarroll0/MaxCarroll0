-- scripts/lib/util.lua: shell-out, logging and formatting helpers

local util = {}

function util.log(fmt, ...)
  io.stderr:write(fmt:format(...), "\n")
end

function util.shq(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function util.run(cmd)
  local f = io.popen(cmd, "r")
  if not f then
    return nil, -1
  end
  local out = f:read("a") or ""
  local ok, _, code = f:close()
  return out, ok and 0 or (code or 1)
end

function util.rimraf(path)
  os.execute("rm -rf -- " .. util.shq(path))
end

function util.mkdirp(path)
  os.execute("mkdir -p -- " .. util.shq(path))
end

function util.email_set(emails)
  local set = {}
  for _, e in ipairs(emails) do
    set[e:lower()] = true
  end
  return set
end

function util.author_flags(emails)
  local parts = {}
  for _, e in ipairs(emails) do
    parts[#parts + 1] = "--author=" .. util.shq(e)
  end
  return table.concat(parts, " ")
end

function util.commas(n)
  local s = tostring(math.floor(n + 0.5))
  s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  return (s:gsub("^,", ""))
end

function util.esc(s)
  return (s:gsub("[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

-- Display width: codepoints not bytes (bar glyphs █/░ are 3 bytes, 1 column).
function util.dwidth(s)
  return utf8.len(s) or #s
end

-- Normalise a language display name to a langurls key; gen-langurls.lua builds the table's keys the same way.
function util.normkey(s)
  s = s:lower():gsub("%s*%b()", ""):gsub("%s+header$", ""):gsub(" sharp", "#")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

return util
