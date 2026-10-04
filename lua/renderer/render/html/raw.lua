local Element = require('renderer.render.html.element')

---Replaces a `script` or `style` element with one summary line
---@class renderer.render.html.Raw: renderer.render.html.Element
local Render = setmetatable({}, Element)
Render.__index = Render

---@private
---@type table<string, string>
Render.icons = {
    script = '󰌞 ',
    style = '󰌜 ',
}

---@protected
---@return boolean
function Render:enabled()
    return self:structure()
        and self:alone(self.node)
        and not Render.in_head(self.node)
end

---The head renders itself as a whole, including what is inside
---@private
---@param node renderer.Node
---@return boolean
function Render.in_head(node)
    local parent = node:parent('element')
    while parent do
        if Element.name_of(parent) == 'head' then
            return true
        end
        parent = parent:parent('element')
    end
    return false
end

---@protected
function Render:run()
    local count = self.node:height()
    local text = ('%s%s (%d %s)'):format(
        self.icons[self.name] or '',
        self.name,
        count,
        count == 1 and 'line' or 'lines'
    )
    local lines = { { { text, 'RendererHtmlComment' } } }
    self.marks:replace(self.config, self.node, lines)
end

return Render
