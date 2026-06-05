-- scripts/lib/inject.lua: replace the text between a marker pair, keeping the markers; idempotent

local inject = {}

function inject.replace(text, start_marker, end_marker, body)
  local si = text:find(start_marker, 1, true)
  if not si then
    return nil, "start marker not found: " .. start_marker
  end
  local ei = text:find(end_marker, si, true)
  if not ei then
    return nil, "end marker not found: " .. end_marker
  end

  local head = text:sub(1, si + #start_marker - 1)
  local tail = text:sub(ei)
  return head .. "\n\n" .. body .. "\n\n" .. tail
end

return inject
