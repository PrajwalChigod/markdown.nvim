local Base = require('render-markdown.render.base')
local env = require('render-markdown.lib.env')
local str = require('render-markdown.lib.str')

---@class render.md.render.html.Tag: render.md.Render
---@field private config render.md.html.Config
local Render = setmetatable({}, Base)
Render.__index = Render

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
    self:align(name.text, start_tag, end_tag)
end

---Center or right align the lines of an element, like Github does for
---`align="center"` and `<center>`
---@private
---@param name string
---@param start_tag render.md.Node
---@param end_tag? render.md.Node
function Render:align(name, start_tag, end_tag)
    local align = Render.attribute(start_tag.text, 'align')
    if name:lower() == 'center' then
        align = 'center'
    end
    if (align ~= 'center' and align ~= 'right') or not end_tag then
        return
    end
    local width = env.win.width(self.context.win)
    local lines = vim.api.nvim_buf_get_lines(
        self.context.buf,
        start_tag.start_row,
        end_tag.end_row + 1,
        false
    )
    for i, line in ipairs(lines) do
        local row = start_tag.start_row + i - 1
        local col = line:find('%S')
        local first = row == start_tag.start_row
        local last = row == end_tag.end_row
        local skip = not col
            or self.centered(self.marks, row)
            or (first and line:sub(1, start_tag.start_col):find('%S'))
            or (last and line:sub(end_tag.end_col + 1):find('%S'))
        if not skip then
            local text = self.visible(self.config, vim.trim(line))
            local space = width - str.width(text)
            local pad = align == 'center' and math.floor(space / 2) or space
            if text ~= '' and pad > 0 then
                self.centered(self.marks, row, true)
                self.marks:add(self.config, false, row, col - 1, {
                    virt_text = { { (' '):rep(pad), 'Normal' } },
                    virt_text_pos = 'inline',
                })
            end
        end
    end
end

---rows that already have alignment, so nested elements do not add it twice
---@private
---@type table<render.md.Marks, table<integer, boolean>>
Render.rows = setmetatable({}, { __mode = 'k' })

---@private
---@param marks render.md.Marks
---@param row integer
---@param set? boolean
---@return boolean
function Render.centered(marks, row, set)
    local rows = Render.rows[marks]
    if not rows then
        rows = {}
        Render.rows[marks] = rows
    end
    if set then
        rows[row] = true
    end
    return rows[row] == true
end

---text of a line as it appears once tags are concealed
---@private
---@param config render.md.html.Config
---@param line string
---@return string
function Render.visible(config, line)
    local text = line:gsub('<img[^>]*>', function(tag)
        local img = config.tag.img
        local alt = img and img.attribute and Render.attribute(tag, img.attribute)
        return (img and img.icon or '') .. (alt or '')
    end)
    text = text:gsub('<[^>]*>', '')
    return text
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
