local Element = require('renderer.render.html.element')

---Replaces `head` with the text of its `title`
---@class renderer.render.html.Head: renderer.render.html.Element
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    return self:structure() and self:alone(self.node)
end

---@protected
function Render:run()
    local title = self:title()
    if title then
        local lines = { { { title, 'RendererHtmlBold' } } }
        self.marks:replace(self.config, self.node, lines)
    else
        self.marks:over(self.config, true, self.node, { conceal_lines = '' })
    end
end

---@private
---@return string?
function Render:title()
    local result ---@type string?
    self.node:for_each_child(function(child)
        if child.type == 'element' and Element.name_of(child) == 'title' then
            local text = child:child('text')
            result = result or text and vim.trim(text.text)
        end
    end)
    return result ~= '' and result or nil
end

return Render
