-- scripts/lib/blame.lua: attribute final-state non-blank lines to the user via git blame, deduped by origin.
-- Tallies two buckets: all-time (your email) and recent (your email AND author-time >= cutoff, i.e. lines you wrote
-- inside the window that still survive). For .org files a per-line language map reattributes tangled src blocks.

local util = require("lib.util")

local blame = {}

local function touched_files(path, emails, since)
  local sincearg = since and (" --since=" .. util.shq(since)) or ""
  local cmd = ("git -C %s log --fixed-strings %s%s --name-only --diff-filter=d --pretty=format: HEAD -- 2>/dev/null"):format(
    util.shq(path),
    util.author_flags(emails),
    sincearg
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
-- `org` (optional) maps a final line number -> language; otherwise the file's single `deflang` is used.
local function count_file(path, file, flags, email_set, seen, cutoff, deflang, org, alltime, recent)
  local cmd = ("git -C %s blame %s --line-porcelain HEAD -- %s 2>/dev/null"):format(
    util.shq(path),
    flags,
    util.shq(file)
  )
  local out = util.run(cmd)
  if not out or out == "" then
    return 0
  end

  local n = 0
  local sha, orig, final, mail, atime, ofile
  for line in (out .. "\n"):gmatch("(.-)\n") do
    local hsha, horig, hfinal = line:match("^(%x+) (%d+) (%d+)")
    if hsha and #hsha >= 7 then
      sha, orig, final, mail, atime, ofile = hsha, horig, tonumber(hfinal), nil, nil, file
    elseif line:byte(1) == 9 then
      if mail and email_set[mail] and line:sub(2):match("%S") then
        local key = sha .. ":" .. ofile .. ":" .. orig
        if not seen[key] then
          seen[key] = true
          local lang = (org and org[final]) or deflang
          if lang then
            if alltime then
              alltime[lang] = (alltime[lang] or 0) + 1
            end
            if recent and atime and atime >= cutoff then
              recent[lang] = (recent[lang] or 0) + 1
            end
            n = n + 1
          end
        end
      end
    else
      local m = line:match("^author%-mail <(.*)>$")
      if m then
        mail = m:lower()
      else
        local at = line:match("^author%-time (%d+)$")
        if at then
          atime = tonumber(at)
        else
          local fn = line:match("^filename (.+)$")
          if fn then
            ofile = fn
          end
        end
      end
    end
  end
  return n
end

-- p: { path, emails, email_set, flags, file_lang, org_lines?, seen, cutoff, since?, alltime?, recent? }
-- `since` limits the scan to files touched in the window (cheap recent-only pass for owned repos).
function blame.attribute(p)
  local files = touched_files(p.path, p.emails, p.since)
  local blamed = 0
  for _, file in ipairs(files) do
    local org = p.org_lines and p.org_lines[file]
    local deflang = p.file_lang[file]
    if deflang or org then
      local n = count_file(p.path, file, p.flags, p.email_set, p.seen, p.cutoff, deflang, org, p.alltime, p.recent)
      if n > 0 then
        blamed = blamed + 1
      end
    end
  end
  return #files, blamed
end

return blame
