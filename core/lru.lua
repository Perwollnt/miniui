local M = {}

function M.new(max_entries)
  local self = {
    max_entries = math.max(1, tonumber(max_entries) or 32),
    size = 0,
    values = {},
    order = {},
  }

  function self:get(key)
    local v = self.values[key]
    if v == nil then
      return nil
    end
    self:touch(key)
    return v
  end

  function self:touch(key)
    local order = self.order
    for i = 1, #order do
      if order[i] == key then
        table.remove(order, i)
        break
      end
    end
    order[#order + 1] = key
  end

  function self:set(key, value)
    if self.values[key] == nil then
      self.size = self.size + 1
    end
    self.values[key] = value
    self:touch(key)
    while self.size > self.max_entries do
      local old = table.remove(self.order, 1)
      if old ~= nil and self.values[old] ~= nil then
        self.values[old] = nil
        self.size = self.size - 1
      end
    end
  end

  return self
end

return M
