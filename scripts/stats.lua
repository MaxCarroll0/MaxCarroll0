-- scripts/stats.lua: compute per-language line stats across owned + external repos; inject Markdown tables into the README.

local here = arg[0]:match("(.*[/\\])") or "./"
package.path = here .. "?.lua;" .. package.path

local util = require("lib.util")
local conf = require("lib.conf")
local github = require("lib.github")
local repos = require("lib.repos")
local tokei = require("lib.tokei")
local blame = require("lib.blame")
local orgtangle = require("lib.orgtangle")
local aggregate = require("lib.aggregate")
local langgroups = require("lib.langgroups")
local langurls = require("lib.langurls")
local render = require("lib.render")
local inject = require("lib.inject")

local config = conf.load("config.toml")

local opts = { dry_run = false, only = nil }
for _, a in ipairs(arg) do
  if a == "--dry-run" then
    opts.dry_run = true
  elseif a:match("^--only=") then
    opts.only = a:sub(8)
  elseif a == "--help" then
    print("usage: lua scripts/stats.lua [--dry-run] [--only=SUBSTR]")
    os.exit(0)
  end
end

local function selected(name)
  return (not opts.only) or name:lower():find(opts.only:lower(), 1, true) ~= nil
end

local emails = config.identities.emails
local email_set = util.email_set(emails)
local flags = config.counting.blame_flags or "-w"
local recent_days = config.recent.days or 90
local token = os.getenv("GH_TOKEN") or os.getenv("GITHUB_TOKEN") or os.getenv("GH_PAT")
local excludes = config.counting.exclude
local cutoff = os.time() - recent_days * 86400 -- author-time floor: lines you wrote inside the window
local since_str = recent_days .. " days ago"

local alltime, recent = {}, {}
local top_contrib, recent_contrib = {}, {} -- lang -> repo label -> lines, for the per-row dropdowns
local is_private = {} -- repo label -> bool
local seen = {}
local n_owned, n_ext = 0, 0

local function add_contrib(store, lang, label, n)
  if n <= 0 then
    return
  end
  local by = store[lang]
  if not by then
    by = {}
    store[lang] = by
  end
  by[label] = (by[label] or 0) + n
end

util.rimraf(config.work_dir)
util.mkdirp(config.work_dir)

if config.owned.enabled and selected("owned") then
  util.log("== owned repos (tokei wholesale) ==")
  local list, err = github.owned_repos(config.owned)
  if not list then
    util.log("! owned discovery failed: %s", err or "?")
  else
    util.log("discovered %d owned repo(s)", #list)
    for _, r in ipairs(list) do
      if selected(r.full_name or r.name) then
        local label = r.full_name or r.name
        is_private[label] = r.private == true
        local ok, e = pcall(function()
          local prep = assert(repos.prepare_owned(r, token, config.work_dir, recent_days))
          local tk = assert(tokei.analyze(prep.path, excludes))
          local org = orgtangle.scan(prep.path, tk.file_lang)
          for lang, s in pairs(tk.lang_totals) do
            if lang ~= "Org" then -- .org reattributed below: tangled src blocks count as their own language
              local n = s.code + s.comments
              alltime[lang] = (alltime[lang] or 0) + n
              add_contrib(top_contrib, lang, label, n)
            end
          end
          for lang, n in pairs(org.totals) do
            alltime[lang] = (alltime[lang] or 0) + n
            add_contrib(top_contrib, lang, label, n)
          end
          local rec_sink = {}
          blame.attribute({
            path = prep.path,
            emails = emails,
            email_set = email_set,
            flags = flags,
            file_lang = tk.file_lang,
            org_lines = org.lines,
            seen = seen,
            cutoff = cutoff,
            since = since_str,
            recent = rec_sink,
          })
          for lang, n in pairs(rec_sink) do
            recent[lang] = (recent[lang] or 0) + n
            add_contrib(recent_contrib, lang, label, n)
          end
          util.rimraf(prep.path)
        end)
        if ok then
          n_owned = n_owned + 1
        else
          util.log("  ! %s: %s", r.full_name or r.name, e)
        end
      end
    end
  end
end

util.log("== external repos (blame attribution) ==")
for _, g in ipairs(repos.group_external(config.external)) do
  local key = g.owner .. "/" .. g.repo
  if selected(key) then
    is_private[key] = g.private == true
    local ok, e = pcall(function()
      local prep = assert(repos.prepare_external(g.owner, g.repo, g.refs, token, config.work_dir))
      local at_sink, rec_sink = {}, {}
      for _, unit in ipairs(prep.units) do
        local tk = assert(tokei.analyze(unit.path, excludes))
        local org = orgtangle.scan(unit.path, tk.file_lang)
        local touched, blamed = blame.attribute({
          path = unit.path,
          emails = emails,
          email_set = email_set,
          flags = flags,
          file_lang = tk.file_lang,
          org_lines = org.lines,
          seen = seen,
          cutoff = cutoff,
          alltime = at_sink,
          recent = rec_sink,
        })
        util.log("  %s@%s: %d file(s) touched, %d blamed", key, unit.ref, touched, blamed)
      end
      for lang, n in pairs(at_sink) do
        alltime[lang] = (alltime[lang] or 0) + n
        add_contrib(top_contrib, lang, key, n)
      end
      for lang, n in pairs(rec_sink) do
        recent[lang] = (recent[lang] or 0) + n
        add_contrib(recent_contrib, lang, key, n)
      end
      util.rimraf(prep.maindir)
    end)
    if ok then
      n_ext = n_ext + 1
    else
      util.log("  ! %s: %s", key, e)
    end
  end
end

util.rimraf(config.work_dir)

local gopts = {
  merge = config.languages.merge,
  hide = config.languages.hide,
  group_order = config.groups.order,
  per_group = config.groups.per_group,
  per_group_overrides = config.groups.per_group_overrides,
  other_label = config.groups.other_label,
  group_of = function(l)
    return langgroups.group_of(l, config.groups)
  end,
}
local top_g = aggregate.grouped(alltime, gopts)
local recent_g = aggregate.grouped(recent, gopts)
local bopts = {
  merge = config.languages.merge,
  hide = config.languages.hide,
  private_label = (config.breakdown and config.breakdown.private_label) or "Private",
}
local top_bd = aggregate.breakdown(top_contrib, is_private, bopts)
local recent_bd = aggregate.breakdown(recent_contrib, is_private, bopts)
local function write_assets(root, files)
  util.rimraf(root)
  for p, content in pairs(files) do
    util.mkdirp((p:gsub("/[^/]*$", "")))
    local fh = assert(io.open(p, "w"))
    fh:write(content)
    fh:close()
  end
end

local adir = config.output.assets or "assets"
local cols = config.output.columns
local function render_metric(g, metric, breakdown)
  return render.metric(g, {
    dir = adir,
    metric = metric,
    columns = cols,
    breakdown = breakdown,
    urls = langurls,
    url_overrides = config.languages.urls,
  })
end
local top = render_metric(top_g, "top", top_bd)
local recent = render_metric(recent_g, "recent", recent_bd)
local totals_md = render.totals({
  languages = top_g.count,
  language_names = top_g.languages,
  language_groups = top_g.language_groups,
  lines = top_g.total,
  added = recent_g.total,
  repos = n_owned + n_ext,
  days = recent_days,
})

util.log("== results ==")
util.log("totals: %d repo(s), %d language(s)", n_owned + n_ext, top_g.count)
util.log("top:    %s lines across %d language(s)", util.commas(top_g.total), top_g.count)
util.log("recent: %s lines added (%dd)", util.commas(recent_g.total), recent_days)

if opts.dry_run then
  io.write("\n### TOTALS\n\n", totals_md, "\n\n### TOP\n\n", top.html, "\n\n### RECENT\n\n", recent.html, "\n")
  os.exit(0)
end

local path = config.output.readme
local fh = assert(io.open(path, "r"), "cannot read " .. path)
local text = fh:read("a")
fh:close()

local assets = {}
for p, c in pairs(top.files) do
  assets[p] = c
end
for p, c in pairs(recent.files) do
  assets[p] = c
end
write_assets(adir, assets)

local m = config.output.markers
local new, ierr = inject.replace(text, m.totals.start, m.totals.finish, totals_md)
assert(new, ierr)
new, ierr = inject.replace(new, m.top.start, m.top.finish, top.html)
assert(new, ierr)
new, ierr = inject.replace(new, m.recent.start, m.recent.finish, recent.html)
assert(new, ierr)

if new ~= text then
  local out = assert(io.open(path, "w"))
  out:write(new)
  out:close()
  util.log("updated %s", path)
else
  util.log("%s unchanged", path)
end
