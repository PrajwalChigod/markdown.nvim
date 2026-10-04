local Element = require('renderer.render.html.element')

---@class renderer.render.html.Doctype: renderer.render.html.Element
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.html
    return self:structure()
end

---@protected
function Render:run()
    self:hide(self.node)
end

return Render
