local Element = require('renderer.render.html.element')

---Hides the `html` and `body` tags of a page
---@class renderer.render.html.Page: renderer.render.html.Element
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    return self:structure()
end

---@protected
function Render:run()
    self:hide(self.start_tag)
    self:hide(self.end_tag)
end

return Render
