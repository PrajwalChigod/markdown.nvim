local Element = require('renderer.render.html.element')

---Reduces `head` to the text of its `title`
---@class renderer.render.html.Head: renderer.render.html.Element
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    return self:structure() and self:replaceable(self.node)
end

---@protected
function Render:run()
    local title, text = self:title()
    if not title or not text then
        self.marks:over(self.config, true, self.node, { conceal_lines = '' })
    elseif self:inside(title) then
        self:keep(title)
    else
        local lines = { { { text, 'RendererHtmlBold' } } }
        self.marks:replace(self.config, self.node, lines)
    end
end

---First `title` with text in it
---@private
---@return renderer.Node?, string?
function Render:title()
    local result ---@type renderer.Node?
    local text ---@type string?
    self.node:for_each_child(function(child)
        if child.type == 'element' and Element.name_of(child) == 'title' then
            local node = child:child('text')
            local value = node and vim.trim(node.text) or ''
            if not result and value ~= '' then
                result, text = child, value
            end
        end
    end)
    return result, text
end

---Whether the title has a line of its own between the tags of the head, the
---line can then stay and hold the cursor, which a virtual line cannot
---@private
---@param title renderer.Node
---@return boolean
function Render:inside(title)
    return title.start_row == title.end_row
        and title.start_row > self.node.start_row
        and title.end_row < self.node.end_row
        and self:alone(title)
end

---Hide the lines around the title and the tags of the title
---@private
---@param title renderer.Node
function Render:keep(title)
    self:rows(self.node.start_row, title.start_row - 1)
    self:rows(title.end_row + 1, self.node.end_row)
    local start_tag = title:child('start_tag')
    local end_tag = title:child('end_tag')
    self.marks:over(self.config, true, start_tag, { conceal = '' })
    self.marks:over(self.config, true, end_tag, { conceal = '' })
    if start_tag and end_tag then
        local row, col = start_tag.end_row, start_tag.end_col
        self.marks:add(self.config, true, row, col, {
            end_row = end_tag.start_row,
            end_col = end_tag.start_col,
            hl_group = 'RendererHtmlBold',
        })
    end
end

---@private
---@param first integer
---@param last integer
function Render:rows(first, last)
    local buf = self.context.buf
    local line = vim.api.nvim_buf_get_lines(buf, last, last + 1, false)[1]
    self.marks:add(self.config, true, first, 0, {
        end_row = last,
        end_col = #(line or ''),
        conceal_lines = '',
    })
end

return Render
