-- scripts/lib/langgroups.lua: classify tokei languages by GitHub Linguist's type into display groups.

local TYPES = require("lib.linguist_types")

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

function M.group_of(lang, cfg)
  cfg = cfg or {}
  if cfg.overrides and cfg.overrides[lang] then
    return cfg.overrides[lang]
  end
  local key = lang:lower()
  local t = FIXUP[key] or TYPES[key] or "programming"
  local fold = cfg.fold or {}
  return fold[t] or DEFAULT_FOLD[t] or "Programming"
end

return M
