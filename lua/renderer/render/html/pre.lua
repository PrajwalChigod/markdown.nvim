local Element = require('renderer.render.html.element')

---Adds the code background to each line of a `pre` element
---@class renderer.render.html.Pre: renderer.render.html.Element
---@field private code renderer.code.Config
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    self.code = self.context.config.code
    return self.config.pre and self.code.enabled
end

---@protected
function Render:run()
    local col = self.node.start_col
    for row = self.node.start_row, self.node.end_row do
        self.marks:add(self.code, 'code_background', row, col, {
            end_row = row + 1,
            priority = self.code.priority,
            hl_group = self.code.highlight,
            hl_eol = true,
        })
    end
end

return Render
