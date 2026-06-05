-- scripts/lib/langgroups.lua: classify tokei languages and colour them by GitHub Linguist data

local DATA = require("lib.linguist")

local M = {}

-- tokei names Linguist spells differently or that tokei splits
local FIXUP = {
  ["plain text"] = "prose",
  ["protocol buffers"] = "data",
  ["module-definition"] = "data",
  ["device tree"] = "data",
}

local DEFAULT_FOLD = {
  programming = "Programming",
  prose = "Prose",
  markup = "Prose",
  data = "Configs / Data",
}

-- Resolve a tokei/merged name to its Linguist entry, falling back to the part before "/" (e.g. "OCaml/Reason").
local function entry(key)
  local e = DATA[key]
  if not e then
    local base = key:match("^[^/]+")
    if base and base ~= key then
      e = DATA[(base:gsub("%s+$", ""))]
    end
  end
  return e
end

function M.group_of(lang, cfg)
  cfg = cfg or {}
  if cfg.overrides and cfg.overrides[lang] then
    return cfg.overrides[lang]
  end
  local key = lang:lower()
  local e = entry(key)
  local t = FIXUP[key] or (e and e.t) or "programming"
  local fold = cfg.fold or {}
  return fold[t] or DEFAULT_FOLD[t] or "Programming"
end

local PALETTE =
  { "#6e7781", "#c9510c", "#0969da", "#1a7f37", "#8250df", "#bf3989", "#9a6700", "#0550ae", "#cf222e", "#116329" }

-- Stable palette colour for languages Linguist has no colour for.
local function fallback(lang)
  local h = 5381
  for i = 1, #lang do
    h = (h * 33 + lang:byte(i)) & 0x7fffffff
  end
  return PALETTE[(h % #PALETTE) + 1]
end

function M.color(lang)
  local e = entry(lang:lower())
  return (e and e.c) or fallback(lang)
end

return M
