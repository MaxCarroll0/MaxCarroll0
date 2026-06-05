-- scripts/lib/repos.lua: clone owned/external repos (token auth) and lay out one checkout per ref

local util = require("lib.util")

local repos = {}

-- Disable LFS smudge/process filters: tokei skips LFS binaries anyway, and this avoids needing git-lfs
local CLONE = "git -c filter.lfs.smudge= -c filter.lfs.process= -c filter.lfs.required=false"
  .. " clone --quiet --no-tags"

local function url(owner, name, token)
  local auth = (token and token ~= "") and (token .. "@") or ""
  return "https://" .. auth .. "github.com/" .. owner .. "/" .. name .. ".git"
end

-- Owned: shallow-since clone - final tree for tokei plus in-window history for churn
function repos.prepare_owned(repo, token, root, recent_days)
  local dir = root .. "/owned/" .. repo.owner .. "__" .. repo.name
  util.rimraf(dir)
  local since = (recent_days or 90) + 14
  local u = url(repo.owner, repo.name, token)
  local base = CLONE .. " --single-branch "
  local _, code = util.run(
    base
      .. "--shallow-since="
      .. util.shq(since .. " days ago")
      .. " "
      .. util.shq(u)
      .. " "
      .. util.shq(dir)
      .. " 2>/dev/null"
  )
  if code ~= 0 then
    util.rimraf(dir)
    _, code = util.run(base .. "--depth 1 " .. util.shq(u) .. " " .. util.shq(dir) .. " 2>/dev/null")
    if code ~= 0 then
      return nil, "clone failed: " .. repo.owner .. "/" .. repo.name
    end
  end
  return { path = dir }
end

-- External: full clone (blame needs history)
function repos.prepare_external(owner, name, refs, token, root)
  local maindir = root .. "/ext/" .. owner .. "__" .. name
  util.rimraf(maindir)
  local _, code =
    util.run(CLONE .. " " .. util.shq(url(owner, name, token)) .. " " .. util.shq(maindir) .. " 2>/dev/null")
  if code ~= 0 then
    return nil, "clone failed: " .. owner .. "/" .. name
  end

  local units = {}
  for _, ref in ipairs(refs) do
    if ref == "" then
      units[#units + 1] = { ref = "(default)", path = maindir }
    else
      local wt = maindir .. "__wt__" .. ref:gsub("[^%w%-_]", "_")
      util.rimraf(wt)
      local _, c = util.run(
        ("git -C %s worktree add --detach --quiet %s %s 2>/dev/null"):format(
          util.shq(maindir),
          util.shq(wt),
          util.shq("origin/" .. ref)
        )
      )
      if c ~= 0 then
        _, c = util.run(
          ("git -C %s worktree add --detach --quiet %s %s 2>/dev/null"):format(
            util.shq(maindir),
            util.shq(wt),
            util.shq(ref)
          )
        )
      end
      if c == 0 then
        units[#units + 1] = { ref = ref, path = wt }
      else
        util.log("  ! %s/%s: ref %s not found", owner, name, ref)
      end
    end
  end
  return { maindir = maindir, units = units }
end

return repos
