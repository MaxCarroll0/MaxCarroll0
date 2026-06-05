-- scripts/lib/json.lua: minimal JSON decoder

local json = {}

json.null = setmetatable({}, {
  __tostring = function()
    return "null"
  end,
})

local parse_value

local function err(pos, msg)
  error(("json: %s at byte %d"):format(msg, pos), 0)
end

local function skip_ws(s, i)
  local _, e = s:find("^[ \t\r\n]*", i)
  return e + 1
end

local escapes = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

local function parse_string(s, i)
  local buf, j = {}, i + 1
  while true do
    local a, b, chunk, term = s:find('([^"\\]*)(["\\])', j)
    if not a then
      err(j, "unterminated string")
    end
    buf[#buf + 1] = chunk
    if term == '"' then
      return table.concat(buf), b + 1
    end
    local nx = s:sub(b + 1, b + 1)
    if nx == "u" then
      local hex = s:sub(b + 2, b + 5)
      if not hex:match("^%x%x%x%x$") then
        err(b, "bad \\u escape")
      end
      buf[#buf + 1] = utf8.char(tonumber(hex, 16))
      j = b + 6
    else
      local rep = escapes[nx]
      if not rep then
        err(b, "bad escape \\" .. nx)
      end
      buf[#buf + 1] = rep
      j = b + 2
    end
  end
end

local function parse_number(s, i)
  local stop = s:find("[^%-+0-9.eE]", i) or (#s + 1)
  local tok = s:sub(i, stop - 1)
  local n = tonumber(tok)
  if not n then
    err(i, "invalid number '" .. tok .. "'")
  end
  return n, stop
end

local function parse_array(s, i)
  local arr = {}
  i = skip_ws(s, i + 1)
  if s:sub(i, i) == "]" then
    return arr, i + 1
  end
  while true do
    local v
    v, i = parse_value(s, i)
    arr[#arr + 1] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "," then
      i = skip_ws(s, i + 1)
    elseif c == "]" then
      return arr, i + 1
    else
      err(i, "expected ',' or ']'")
    end
  end
end

local function parse_object(s, i)
  local obj = {}
  i = skip_ws(s, i + 1)
  if s:sub(i, i) == "}" then
    return obj, i + 1
  end
  while true do
    if s:sub(i, i) ~= '"' then
      err(i, "expected object key")
    end
    local k
    k, i = parse_string(s, i)
    i = skip_ws(s, i)
    if s:sub(i, i) ~= ":" then
      err(i, "expected ':'")
    end
    local v
    v, i = parse_value(s, skip_ws(s, i + 1))
    obj[k] = v
    i = skip_ws(s, i)
    local c = s:sub(i, i)
    if c == "," then
      i = skip_ws(s, i + 1)
    elseif c == "}" then
      return obj, i + 1
    else
      err(i, "expected ',' or '}'")
    end
  end
end

parse_value = function(s, i)
  i = skip_ws(s, i)
  local c = s:sub(i, i)
  if c == "{" then
    return parse_object(s, i)
  elseif c == "[" then
    return parse_array(s, i)
  elseif c == '"' then
    return parse_string(s, i)
  elseif c == "t" then
    if s:sub(i, i + 3) == "true" then
      return true, i + 4
    end
    err(i, "invalid literal")
  elseif c == "f" then
    if s:sub(i, i + 4) == "false" then
      return false, i + 5
    end
    err(i, "invalid literal")
  elseif c == "n" then
    if s:sub(i, i + 3) == "null" then
      return json.null, i + 4
    end
    err(i, "invalid literal")
  elseif c:match("[%-0-9]") then
    return parse_number(s, i)
  end
  err(i, "unexpected character '" .. c .. "'")
end

function json.decode(s)
  if type(s) ~= "string" then
    error("json.decode expects a string", 2)
  end
  local v = parse_value(s, 1)
  return v
end

return json
