-- scripts/gen-linguist-types.lua: regenerate lib/linguist_types.lua from GitHub Linguist's languages.yml.
-- curl -fsSL <linguist>/lib/linguist/languages.yml | yq -o json | lua scripts/gen-linguist-types.lua > scripts/lib/linguist_types.lua

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

io.write("-- scripts/lib/linguist_types.lua: GENERATED from GitHub Linguist languages.yml; do not edit by hand.\n")
io.write("-- Regenerate with scripts/gen-linguist-types.lua (see its header).\n\n")
io.write("return {\n")
for _, name in ipairs(names) do
  io.write(("  [%q] = %q,\n"):format(name:lower(), data[name].type))
end
io.write("}\n")
