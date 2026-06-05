-- scripts/lib/churn.lua: recent "languages used" from lines added in the window (git log --numstat).

local util = require("lib.util")

local churn = {}

function churn.collect(path, emails, since_days, file_lang, seen_sha, recent)
  local cmd = ("git -C %s log --fixed-strings %s --since=%s --no-merges --no-renames --numstat --pretty=tformat:@%%H HEAD -- 2>/dev/null"):format(
    util.shq(path),
    util.author_flags(emails),
    util.shq(since_days .. " days ago")
  )
  local out = util.run(cmd)
  if not out or out == "" then
    return
  end

  local skip = false
  for line in (out .. "\n"):gmatch("(.-)\n") do
    local sha = line:match("^@(%x+)$")
    if sha then
      skip = seen_sha[sha] == true
      seen_sha[sha] = true
    elseif not skip and line ~= "" then
      local add, file = line:match("^(%d+)\t%d+\t(.+)$")
      if add then
        local lang = file_lang[file]
        if lang then
          recent[lang] = (recent[lang] or 0) + tonumber(add)
        end
      end
    end
  end
end

return churn
