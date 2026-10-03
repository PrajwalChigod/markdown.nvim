---@class renderer.test.Marks
---@field private marks renderer.test.MarkInfo[]
local Marks = {}
Marks.__index = Marks

---@return renderer.test.Marks
function Marks.new()
    local self = setmetatable({}, Marks)
    self.marks = {}
    return self
end

---@return renderer.test.MarkInfo[]
function Marks:get()
    table.sort(self.marks, function(a, b)
        return require('tests.helpers.details').__lt(a, b)
    end)
    return self.marks
end

---@param other renderer.test.Marks
---@return renderer.test.Marks
function Marks:extend(other)
    vim.list_extend(self.marks, other.marks)
    return self
end

---@param row renderer.test.Range|integer
---@param col renderer.test.Range|integer
---@param opts vim.api.keyset.set_extmark
function Marks:add(row, col, opts)
    ---@type renderer.test.MarkInfo
    ---@diagnostic disable-next-line: assign-type-mismatch
    local mark = opts
    mark.row = Marks.range(row)
    mark.col = Marks.range(col)
    self.marks[#self.marks + 1] = mark
end

---@private
---@param r renderer.test.Range|integer
---@return renderer.test.Range
function Marks.range(r)
    if type(r) == 'table' then
        return r
    elseif type(r) == 'number' then
        ---@type renderer.test.Range
        return { r }
    else
        error(('invalid range type: %s'):format(type(r)))
    end
end

return Marks
