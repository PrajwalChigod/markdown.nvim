---@class renderer.test.Row
---@field private value integer
local Row = {}
Row.__index = Row

---@return renderer.test.Row
function Row.new()
    local self = setmetatable({}, Row)
    self.value = 0
    return self
end

---@param soff integer
---@param eoff? integer
---@return renderer.test.Range
function Row:get(soff, eoff)
    ---@type renderer.test.Range
    return { self:inc(soff), eoff and self:inc(eoff) or nil }
end

---@private
---@param n integer
---@return integer
function Row:inc(n)
    self.value = self.value + n
    return self.value
end

return Row
