local interval = require('renderer.lib.interval')
local str = require('renderer.lib.str')

---@class renderer.Line
---@field private highlight string
---@field private previous? renderer.mark.Hl
---@field private line renderer.mark.Line
local Line = {}
Line.__index = Line

---@param highlight string
---@return renderer.Line
function Line.new(highlight)
    local self = setmetatable({}, Line)
    self.highlight = highlight
    self.previous = nil
    self.line = {}
    return self
end

---@return renderer.mark.Line
function Line:get()
    return self.line
end

---@return boolean
function Line:empty()
    return #self.line == 0
end

---@return integer
function Line:width()
    return str.line_width(self.line)
end

---@param other renderer.Line|renderer.mark.Line
---@return renderer.Line
function Line:extend(other)
    local line = other.line or other
    for _, text in ipairs(line) do
        self:add(text[1], text[2])
    end
    return self
end

---@return renderer.Line
function Line:copy()
    return Line.new(self.highlight):extend(self)
end

---@param i integer 1-based inclusive
---@param j integer 1-based inclusive
---@return renderer.Line
function Line:sub(i, j)
    local result = Line.new(self.highlight)
    local position = 0
    for _, text in ipairs(self.line) do
        local length = str.width(text[1])
        local range = { i - position, j - position } ---@type renderer.Range
        local overlap = interval.overlap({ 1, length }, range)
        if overlap then
            result:text(str.sub(text[1], overlap[1], overlap[2]), text[2])
        end
        position = position + length
    end
    return result
end

---@param s string
---@param highlight? renderer.mark.Hl
---@return renderer.Line
function Line:text(s, highlight)
    if #s > 0 then
        self:add(s, highlight)
    end
    return self
end

---@param n integer
---@param highlight? renderer.mark.Hl
---@return renderer.Line
function Line:pad(n, highlight)
    return self:rep(' ', n, highlight)
end

---@param s string
---@param n integer
---@param highlight? renderer.mark.Hl
---@return renderer.Line
function Line:rep(s, n, highlight)
    if n > 0 then
        self:add(s:rep(n), highlight)
    end
    return self
end

---@private
---@param text string
---@param highlight? renderer.mark.Hl
function Line:add(text, highlight)
    highlight = highlight or self.highlight
    if highlight == self.previous then
        self.line[#self.line][1] = self.line[#self.line][1] .. text
    else
        self.line[#self.line + 1] = { text, highlight }
        self.previous = highlight
    end
end

return Line
