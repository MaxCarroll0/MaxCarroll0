-- scripts/lib/conf.lua: load a TOML config by converting it to JSON with yq, then decoding.

local json = require("lib.json")
local util = require("lib.util")

local conf = {}

local function has(tool)
  local out = util.run("command -v " .. util.shq(tool) .. " 2>/dev/null")
  return out and out:match("%S") ~= nil
end

local function converters(q)
  return {
    { "yq", "yq -p toml -o json " .. q },
    { "tomljson", "tomljson " .. q },
    { "taplo", "taplo get -o json -f " .. q .. " ." },
  }
end

function conf.load(path)
  local f = io.open(path, "r")
  if not f then
    error("cannot open " .. path)
  end
  f:close()
  for _, c in ipairs(converters(util.shq(path))) do
    if has(c[1]) then
      local out, code = util.run(c[2] .. " 2>/dev/null")
      if code == 0 and out and out:match("%S") then
        local ok, data = pcall(json.decode, out)
        if ok then
          return data
        end
        error(("%s produced invalid JSON for %s"):format(c[1], path))
      end
    end
  end
  error("no TOML->JSON converter found; install one of: yq, tomljson, taplo")
end

return conf
