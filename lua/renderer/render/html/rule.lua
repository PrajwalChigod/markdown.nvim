local Element = require('renderer.render.html.element')
local env = require('renderer.lib.env')

---Replaces an `hr` element with a line, like a markdown thematic break
---@class renderer.render.html.Rule: renderer.render.html.Element
---@field private dash renderer.dash.Config
---@field private width integer
---@field private margin integer
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    self.dash = self.context.config.dash
    if not self.config.rule or not self.dash.enabled then
        return false
    end
    self.width = self:get_width(self.dash.width, 0)
    self.margin = self:get_width(self.dash.left_margin, self.width)
    -- the line is drawn over the source so nothing else can share the row
    return self.width > 0 and self:alone(self.node)
end

---@private
---@param width renderer.dash.Width
---@param used integer
---@return integer
function Render:get_width(width, used)
    if type(width) == 'number' then
        return env.win.percent(self.context.win, width, used)
    elseif type(width) == 'function' then
        return width({ width = env.win.width(self.context.win) })
    else
        return vim.o.columns
    end
end

---@protected
function Render:run()
    local line = self:line():pad(self.margin)
    line:rep(self.dash.icon, self.width, self.dash.highlight)
    self.marks:add(self.dash, 'dash', self.node.start_row, 0, {
        priority = self.dash.priority,
        virt_text = line:get(),
        virt_text_pos = 'overlay',
    })
end

return Render
