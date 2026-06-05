-- scripts/lib/blame.lua: attribute final-state non-blank lines to the user via git blame, deduped by origin.

local util = require("lib.util")

local blame = {}

local function touched_files(path, emails)
  local cmd = ("git -C %s log --fixed-strings %s --name-only --diff-filter=d --pretty=format: HEAD -- 2>/dev/null"):format(
    util.shq(path),
    util.author_flags(emails)
  )
  local out = util.run(cmd) or ""
  local set, list = {}, {}
  for f in out:gmatch("[^\n]+") do
    if not set[f] then
      set[f] = true
      list[#list + 1] = f
    end
  end
  return list
end

-- `seen` keys by origin commit:path:line, so shared-history lines across units count once.
local function count_file(path, file, flags, email_set, seen)
  local cmd = ("git -C %s blame %s --line-porcelain HEAD -- %s 2>/dev/null"):format(
    util.shq(path),
    flags,
    util.shq(file)
  )
  local out = util.run(cmd)
  if not out or out == "" then
    return 0
  end

  local n, sha, orig, mail, ofile = 0
  for line in (out .. "\n"):gmatch("(.-)\n") do
    local hsha, horig = line:match("^(%x+) (%d+) %d+")
    if hsha and #hsha >= 7 then
      sha, orig, mail, ofile = hsha, horig, nil, file
    elseif line:byte(1) == 9 then
      if mail and email_set[mail] and line:sub(2):match("%S") then
        local key = sha .. ":" .. ofile .. ":" .. orig
        if not seen[key] then
          seen[key] = true
          n = n + 1
        end
      end
    else
      local m = line:match("^author%-mail <(.*)>$")
      if m then
        mail = m:lower()
      else
        local fn = line:match("^filename (.+)$")
        if fn then
          ofile = fn
        end
      end
    end
  end
  return n
end

function blame.attribute(path, emails, email_set, flags, file_lang, seen, alltime)
  local files = touched_files(path, emails)
  local blamed = 0
  for _, file in ipairs(files) do
    local lang = file_lang[file]
    if lang then
      blamed = blamed + 1
      local n = count_file(path, file, flags, email_set, seen)
      if n > 0 then
        alltime[lang] = (alltime[lang] or 0) + n
      end
    end
  end
  return #files, blamed
end

return blame
