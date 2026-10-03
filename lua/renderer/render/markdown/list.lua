local Base = require('renderer.render.base')
local Bullet = require('renderer.render.markdown.bullet')
local Checkbox = require('renderer.render.markdown.checkbox')

---@class renderer.render.List: renderer.Render
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    return true
end

---@protected
function Render:run()
    if not Checkbox:execute(self.context, self.marks, self.node) then
        Bullet:execute(self.context, self.marks, self.node)
    end
end

return Render
