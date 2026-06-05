-- scripts/lib/svg.lua: build the small SVGs (per-row bars, stacked proportion bars) embedded in the README

local util = require("lib.util")

local svg = {}

local FONT = "-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif"
local TRACK, TRACK_OP = "#808080", "0.22"

local esc = util.esc

-- Outlined box at 100% with a left-to-right colour fill to `frac`. Returns (svg, fill_px) to name the file.
function svg.rowbar(frac, color, w, h)
  w, h = w or 90, h or 12
  local iw = w - 2
  local fill = math.max(0, math.min(iw, math.floor(frac * iw + 0.5)))
  local s = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">'):format(w, h)
  if fill > 0 then
    s = s .. ('<rect x="1" y="1" width="%d" height="%d" rx="2" fill="%s"/>'):format(fill, h - 2, color)
  end
  s = s
    .. ('<rect x="0.5" y="0.5" width="%s" height="%s" rx="3" fill="none" stroke="%s" stroke-opacity="0.55"/>'):format(
      w - 1,
      h - 1,
      TRACK
    )
  return s .. "</svg>", fill
end

-- Stacked proportion bar with a coloured title above it. segments: list of {frac, color}; remainder is "Other".
function svg.stacked(title, title_color, segments, w)
  w = w or 280
  local bh, by = 12, 23
  local h = by + bh
  local title_tag = ('<text x="0" y="14" font-family="%s" font-size="13" font-weight="600" fill="%s">%s</text>'):format(
    FONT,
    title_color,
    esc(title)
  )
  local bars, x = {}, 0
  for _, seg in ipairs(segments) do
    local sw = seg.frac * w
    if sw > 0 then
      bars[#bars + 1] = ('<rect x="%.2f" y="%d" width="%.2f" height="%d" fill="%s"/>'):format(x, by, sw, bh, seg.color)
      x = x + sw
    end
  end
  if x < w then
    bars[#bars + 1] = ('<rect x="%.2f" y="%d" width="%.2f" height="%d" fill="%s" fill-opacity="%s"/>'):format(
      x,
      by,
      w - x,
      bh,
      TRACK,
      TRACK_OP
    )
  end
  return (
    '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d">%s'
    .. '<clipPath id="c"><rect y="%d" width="%d" height="%d" rx="4"/></clipPath>'
    .. '<g clip-path="url(#c)">%s</g></svg>'
  ):format(w, h, title_tag, by, w, bh, table.concat(bars))
end

-- Small filled circle used as a colour swatch before a language name.
function svg.dot(color)
  return ('<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><circle cx="5" cy="5" r="5" fill="%s"/></svg>'):format(
    color
  )
end

return svg
