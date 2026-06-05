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

local function clone(flags, u, dir)
  local _, code = util.run(("%s %s %s %s 2>/dev/null"):format(CLONE, flags, util.shq(u), util.shq(dir)))
  return code
end

local function add_worktree(maindir, wt, rev)
  local _, code = util.run(
    ("git -C %s worktree add --detach --quiet %s %s 2>/dev/null"):format(util.shq(maindir), util.shq(wt), util.shq(rev))
  )
  return code
end

-- Owned: shallow-since clone - final tree for tokei plus in-window history for churn
function repos.prepare_owned(repo, token, root, recent_days)
  local dir = root .. "/owned/" .. repo.owner .. "__" .. repo.name
  util.rimraf(dir)
  local since = (recent_days or 90) + 14
  local u = url(repo.owner, repo.name, token)
  if clone("--single-branch --shallow-since=" .. util.shq(since .. " days ago"), u, dir) ~= 0 then
    util.rimraf(dir)
    if clone("--single-branch --depth 1", u, dir) ~= 0 then
      return nil, "clone failed: " .. repo.owner .. "/" .. repo.name
    end
  end
  return { path = dir }
end

-- External: full clone (blame needs history)
function repos.prepare_external(owner, name, refs, token, root)
  local maindir = root .. "/ext/" .. owner .. "__" .. name
  util.rimraf(maindir)
  if clone("", url(owner, name, token), maindir) ~= 0 then
    return nil, "clone failed: " .. owner .. "/" .. name
  end

  local units = {}
  for _, ref in ipairs(refs) do
    if ref == "" then
      units[#units + 1] = { ref = "(default)", path = maindir }
    else
      local wt = maindir .. "__wt__" .. ref:gsub("[^%w%-_]", "_")
      util.rimraf(wt)
      local code = add_worktree(maindir, wt, "origin/" .. ref)
      if code ~= 0 then
        code = add_worktree(maindir, wt, ref)
      end
      if code == 0 then
        units[#units + 1] = { ref = ref, path = wt }
      else
        util.log("  ! %s/%s: ref %s not found", owner, name, ref)
      end
    end
  end
  return { maindir = maindir, units = units }
end

function repos.group_external(externals)
  local by_key, order = {}, {}
  for _, e in ipairs(externals) do
    local key = e.owner .. "/" .. e.repo
    if not by_key[key] then
      by_key[key] = { owner = e.owner, repo = e.repo, refs = {}, private = false }
      order[#order + 1] = by_key[key]
    end
    by_key[key].refs[#by_key[key].refs + 1] = e.ref or ""
    by_key[key].private = by_key[key].private or e.private == true
  end
  return order
end

return repos
