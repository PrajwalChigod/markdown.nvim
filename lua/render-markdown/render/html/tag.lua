local Base = require('render-markdown.render.base')

---@class render.md.render.html.Tag: render.md.Render
---@field private config render.md.html.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---HTML elements without an end tag
---@private
---@type table<string, boolean>
Render.void = { br = true, hr = true, img = true, input = true, wbr = true }

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.html
    return true
end

---@protected
function Render:run()
    local start_tag = self.node:child('start_tag')
        or self.node:child('self_closing_tag')
    local end_tag = self.node:child('end_tag')
    local name = start_tag and start_tag:child('tag_name')
    if not start_tag or not name then
        return
    end
    Render.apply(self.config, self.marks, name.text, start_tag, end_tag)
end

---@param config render.md.html.Config
---@param marks render.md.Marks
---@param name string
---@param start_tag render.md.Node
---@param end_tag? render.md.Node
function Render.apply(config, marks, name, start_tag, end_tag)
    local tag = config.tag[name:lower()]
    if not tag then
        return
    end

    marks:over(config, true, start_tag, { conceal = '' })
    marks:over(config, true, end_tag, { conceal = '' })

    local text = tag.icon or ''
    if tag.attribute then
        local value = Render.attribute(start_tag.text, tag.attribute)
        text = text .. (value or '')
    end
    if text ~= '' and tag.highlight then
        marks:start(config, false, start_tag, {
            virt_text = { { text, tag.highlight } },
            virt_text_pos = 'inline',
        })
    end

    if tag.scope_highlight and end_tag then
        marks:add(config, true, start_tag.end_row, start_tag.end_col, {
            end_row = end_tag.start_row,
            end_col = end_tag.start_col,
            hl_group = tag.scope_highlight,
        })
    end
end

---@param name string
---@return boolean
function Render.is_void(name)
    return Render.void[name:lower()] == true
end

---@private
---@param text string
---@param name string
---@return string?
function Render.attribute(text, name)
    local pattern = '[%s"\']' .. name .. '%s*=%s*'
    return text:match(pattern .. '"([^"]*)"')
        or text:match(pattern .. "'([^']*)'")
        or text:match(pattern .. '([^%s>"\']+)')
end

return Render
