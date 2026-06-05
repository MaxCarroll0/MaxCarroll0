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

return aggregate
