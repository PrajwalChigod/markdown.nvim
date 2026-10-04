local Element = require('renderer.render.html.element')

---Adds the hyperlink icon before the text of an `a` element
---@class renderer.render.html.Link: renderer.render.html.Element
---@field private link renderer.link.Config
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    self.link = self.context.config.link
    -- anchors without a destination are not links
    return self.name == 'a'
        and self.link.enabled
        and self.start_tag.text:find('%shref%s*=') ~= nil
end

---@protected
function Render:run()
    self.marks:start(self.link, 'link', self.start_tag, {
        virt_text = { { self.link.hyperlink, self.link.highlight } },
        virt_text_pos = 'inline',
    })
end

return Render
