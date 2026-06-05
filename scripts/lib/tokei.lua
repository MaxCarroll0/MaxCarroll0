-- scripts/lib/tokei.lua: run tokei and expose per-language totals plus a file -> language map.

local json = require("lib.json")
local util = require("lib.util")

local tokei = {}

local SKIP = { Total = true }

function tokei.analyze(dir)
  local cmd = "cd " .. util.shq(dir) .. " && tokei --files --output json . 2>/dev/null"
  local out, code = util.run(cmd)
  if not out or out == "" then
    return nil, "tokei produced no output (code " .. code .. ")"
  end

  local data, err = json.safe_decode(out, "tokei")
  if not data then
    return nil, err
  end

  local lang_totals, file_lang = {}, {}
  for lang, info in pairs(data) do
    if not SKIP[lang] and type(info) == "table" then
      lang_totals[lang] = {
        code = info.code or 0,
        comments = info.comments or 0,
        blanks = info.blanks or 0,
      }
      if type(info.reports) == "table" then
        for _, rep in ipairs(info.reports) do
          if type(rep) == "table" and rep.name then
            file_lang[(rep.name:gsub("^%./", ""))] = lang
          end
        end
      end
    end
  end
  return { lang_totals = lang_totals, file_lang = file_lang }
end

return tokei
