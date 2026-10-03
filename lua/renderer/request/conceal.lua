local env = require('renderer.lib.env')
local interval = require('renderer.lib.interval')
local str = require('renderer.lib.str')

---@class renderer.request.Conceal
---@field private context renderer.request.Context
---@field level integer
local Conceal = {}
Conceal.__index = Conceal

---@param context renderer.request.Context
---@return renderer.request.Conceal
function Conceal.new(context)
    local self = setmetatable({}, Conceal)
    self.context = context
    self.level = env.win.get(context.win, 'conceallevel')
    return self
end

---@return boolean
function Conceal:enabled()
    return self.level > 0
end

---@param s string
---@param blocks integer
---@return integer
function Conceal:width(s, blocks)
    if self.level == 1 then
        -- each block is replaced with one character
        return blocks
    elseif self.level == 2 then
        -- replacement characters width is used
        return str.width(s)
    else
        -- text is completely hidden
        return 0
    end
end

---@param s string
---@return string
function Conceal:replacement(s)
    return self.level == 3 and '' or s
end

---@param body renderer.node.Body
---@return boolean
function Conceal:hidden(body)
    if not self:enabled() then
        return false
    end
    return self:line(body).hidden
end

---@param body renderer.node.Body
---@return integer
function Conceal:get(body)
    if not self:enabled() then
        return 0
    end
    local result = 0
    local target = { body.start_col, body.end_col } ---@type renderer.Range
    for _, conceal in ipairs(self:line(body).conceals) do
        local overlap = interval.overlap(conceal, target, true)
        if overlap then
            local text = body.text:sub(
                overlap[1] - target[1] + 1,
                overlap[2] - target[1]
            )
            local concealed = self:width(conceal.replacement, conceal.blocks)
            local width = str.width(text) - concealed
            result = result + width
        end
    end
    return result
end

---@private
---@param body renderer.node.Body
---@return renderer.request.highlights.Line
function Conceal:line(body)
    return self.context.highlights:line(body.start_row)
end

return Conceal
