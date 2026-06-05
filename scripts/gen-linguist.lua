-- scripts/gen-linguist.lua: regenerate lib/linguist.lua (type + color) from GitHub Linguist's languages.yml.
-- curl -fsSL <linguist>/lib/linguist/languages.yml | yq -o json | lua scripts/gen-linguist.lua > scripts/lib/linguist.lua

package.path = (arg[0]:match("(.*/)") or "./") .. "?.lua;" .. package.path
local json = require("lib.json")

local data = json.decode(io.read("a"))
local names = {}
for name, info in pairs(data) do
  if type(info) == "table" and type(info.type) == "string" then
    names[#names + 1] = name
  end
end
table.sort(names)

io.write("-- scripts/lib/linguist.lua: GENERATED from GitHub Linguist languages.yml; do not edit by hand.\n")
io.write("-- Regenerate with scripts/gen-linguist.lua (see its header).\n\n")
io.write("return {\n")
for _, name in ipairs(names) do
  local info = data[name]
  if type(info.color) == "string" then
    io.write(("  [%q] = { t = %q, c = %q },\n"):format(name:lower(), info.type, info.color))
  else
    io.write(("  [%q] = { t = %q },\n"):format(name:lower(), info.type))
  end
end
io.write("}\n")
