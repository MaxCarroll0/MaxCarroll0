-- scripts/gen-langurls.lua: regenerate lib/langurls.lua (language -> homepage) from DBpedia infobox websites.
-- curl -fsSL --data-urlencode 'format=text/tab-separated-values' --data-urlencode query@- \
--   https://dbpedia.org/sparql <<'SPARQL' | lua scripts/gen-langurls.lua > scripts/lib/langurls.lua
-- PREFIX dbo: <http://dbpedia.org/ontology/>
-- PREFIX foaf: <http://xmlns.com/foaf/0.1/>
-- SELECT ?name ?hp WHERE { ?r a dbo:ProgrammingLanguage ; rdfs:label ?name ; foaf:homepage ?hp . FILTER(LANG(?name)="en") }
-- SPARQL
-- Keys are normalised via util.normkey, the same function render.lua resolves display names with.

package.path = (arg[0]:match("(.*/)") or "./") .. "?.lua;" .. package.path
local util = require("lib.util")

local function clean_url(u)
  u = u:gsub("^<", ""):gsub(">$", "")
  u = u:gsub("%%7[Cc].*$", ""):gsub("|.*$", ""):gsub("%s.*$", "") -- drop infobox "a.org|a.org" / trailing junk
  return u
end

local best = {} -- normkey -> { url, score }
for line in io.lines() do
  local name, hp = line:match("^(.-)\t(.+)$")
  if name then
    name = name:match('^"(.*)"@%a+$') or name:match('^"(.*)"$') or name
    local key, url = util.normkey(name), clean_url(hp)
    if key ~= "" and key ~= "name" and url:match("^https?://") then
      local token = key:match("%a%a%a+")
      local score = (url:match("^https://") and 2 or 0) + ((token and url:lower():find(token, 1, true)) and 1 or 0)
      local cur = best[key]
      if not cur or score > cur.score or (score == cur.score and #url < #cur.url) then
        best[key] = { url = url, score = score }
      end
    end
  end
end

local keys = {}
for k in pairs(best) do
  keys[#keys + 1] = k
end
table.sort(keys)

io.write("-- scripts/lib/langurls.lua: language -> homepage, GENERATED from DBpedia; do not edit by hand.\n")
io.write(
  "-- Regenerate with scripts/gen-langurls.lua (see its header). Curate exceptions in config.toml [languages.urls].\n\n"
)
io.write("return {\n")
for _, k in ipairs(keys) do
  io.write(("  [%q] = %q,\n"):format(k, best[k].url))
end
io.write("}\n")
