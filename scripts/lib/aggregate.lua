-- scripts/lib/aggregate.lua: partition a language to count map into display groups with within-group %.

local aggregate = {}

local function apply_merge(map, merge)
  if not merge or not next(merge) then
    return map
  end
  local out = {}
  for lang, v in pairs(map) do
    local tgt = merge[lang] or lang
    out[tgt] = (out[tgt] or 0) + v
  end
  return out
end

function aggregate.grouped(map, opts)
  map = apply_merge(map, opts.merge)
  for _, h in ipairs(opts.hide or {}) do
    map[h] = nil
  end

  local order = {}
  for i, g in ipairs(opts.group_order) do
    order[i] = g
  end

  local buckets, grand, count = {}, 0, 0
  for _, g in ipairs(order) do
    buckets[g] = { name = g, total = 0, rows = {} }
  end
  for lang, v in pairs(map) do
    local g = opts.group_of(lang)
    local b = buckets[g]
    if not b then
      b = { name = g, total = 0, rows = {} }
      buckets[g] = b
      order[#order + 1] = g
    end
    b.rows[#b.rows + 1] = { lang = lang, lines = v }
    b.total = b.total + v
    grand = grand + v
    count = count + 1
  end

  local groups = {}
  for _, g in ipairs(order) do
    local b = buckets[g]
    if b and #b.rows > 0 then
      table.sort(b.rows, function(a, c)
        if a.lines ~= c.lines then
          return a.lines > c.lines
        end
        return a.lang < c.lang
      end)
      for _, r in ipairs(b.rows) do
        r.pct = b.total > 0 and r.lines / b.total * 100 or 0
      end
      if opts.per_group and #b.rows > opts.per_group then
        local t = {}
        for i = 1, opts.per_group do
          t[i] = b.rows[i]
        end
        b.rows = t
      end
      groups[#groups + 1] = b
    end
  end
  return { groups = groups, total = grand, count = count }
end

-- Per-language project split for the row dropdowns. `contrib` is lang -> label -> lines; private
-- labels collapse into one `opts.private_label` row. Each row's pct is its share of the language total.
function aggregate.breakdown(contrib, is_private, opts)
  local merge = opts.merge
  local merged = {}
  for lang, by in pairs(contrib) do
    local tgt = (merge and merge[lang]) or lang
    local m = merged[tgt] or {}
    merged[tgt] = m
    for label, n in pairs(by) do
      m[label] = (m[label] or 0) + n
    end
  end
  for _, h in ipairs(opts.hide or {}) do
    merged[h] = nil
  end

  local priv_label = opts.private_label or "Private"
  local out = {}
  for lang, by in pairs(merged) do
    local rows, priv_lines, priv_repos, total = {}, 0, 0, 0
    for label, n in pairs(by) do
      total = total + n
      if is_private[label] then
        priv_lines = priv_lines + n
        priv_repos = priv_repos + 1
      else
        rows[#rows + 1] = { label = label, lines = n }
      end
    end
    if priv_lines > 0 then
      rows[#rows + 1] = { label = priv_label, lines = priv_lines, private = true, repos = priv_repos }
    end
    table.sort(rows, function(a, c)
      if a.lines ~= c.lines then
        return a.lines > c.lines
      end
      return tostring(a.label) < tostring(c.label)
    end)
    for _, r in ipairs(rows) do
      r.pct = total > 0 and r.lines / total * 100 or 0
    end
    out[lang] = { rows = rows, total = total }
  end
  return out
end

return aggregate
