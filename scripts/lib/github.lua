-- scripts/lib/github.lua: discover the authenticated user's owned repos via gh API

local json = require("lib.json")
local util = require("lib.util")

local github = {}

function github.owned_repos(opts)
  local q = "/user/repos?affiliation=owner&visibility=" .. (opts.visibility or "all") .. "&per_page=100"
  local out, code = util.run("gh api --paginate --slurp " .. util.shq(q) .. " 2>/dev/null")
  if not out or out == "" or code ~= 0 then
    return nil, "gh api failed (code " .. code .. "); check GH_TOKEN / gh auth"
  end

  local ok, pages = pcall(json.decode, out)
  if not ok then
    return nil, "decode failed: " .. tostring(pages)
  end
  if type(pages) ~= "table" then
    return nil, "unexpected gh response"
  end

  local data = {}
  for _, page in ipairs(pages) do
    if type(page) == "table" then
      for _, r in ipairs(page) do
        data[#data + 1] = r
      end
    end
  end

  local repos = {}
  for _, r in ipairs(data) do
    local drop = (r.fork and not opts.include_forks) or (r.archived and not opts.include_archived)
    if not drop and r.name then
      repos[#repos + 1] = {
        owner = type(r.owner) == "table" and r.owner.login or nil,
        name = r.name,
        full_name = r.full_name,
        clone_url = r.clone_url,
        default_branch = r.default_branch,
        private = r.private == true,
      }
    end
  end
  return repos
end

return github
