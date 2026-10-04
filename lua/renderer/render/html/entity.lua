local Base = require('renderer.render.base')
local entities = require('renderer.lib.entities')

---@class renderer.render.html.Entity: renderer.Render
---@field private config renderer.html.Config
---@field private char string
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.html
    if not self.config.entity then
        return false
    end
    -- attribute values are not shown, so there is nothing to replace
    if self.node:parent('attribute') then
        return false
    end
    local char = entities.decode(self.node.text)
    if not char then
        return false
    end
    self.char = char
    return true
end

---@protected
function Render:run()
    -- a conceal replacement is hidden at conceallevel 3, so inline the character
    self.marks:over(self.config, true, self.node, { conceal = '' })
    self.marks:start(self.config, false, self.node, {
        virt_text = { { self.char, '' } },
        virt_text_pos = 'inline',
        hl_mode = 'combine',
    })
end

return Render
