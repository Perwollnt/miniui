local M = {}

-- FNV-1a 32-bit hash. Fast and deterministic in plain Lua.
function M.fnv1a32(s)
  local h = 2166136261
  for i = 1, #s do
    h = bit32.bxor(h, s:byte(i))
    h = (h * 16777619) % 4294967296
  end
  return string.format("%08x", h)
end

return M
