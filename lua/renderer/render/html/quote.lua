local Element = require('renderer.render.html.element')
local list = require('renderer.lib.list')

---Hides the `blockquote` tags and adds the quote icon to each line
---@class renderer.render.html.Quote: renderer.render.html.Element
---@field private quote renderer.quote.Config
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    self.quote = self.context.config.quote
    return self.config.quote and self.quote.enabled
end

---@protected
function Render:run()
    local level = 1
    local parent = self.node:parent('element')
    while parent do
        level = level + (Element.name_of(parent) == 'blockquote' and 1 or 0)
        parent = parent:parent('element')
    end
    local icon = assert(list.cycle(self.quote.icon, level))
    local highlight = assert(list.cycle(self.quote.highlight, level))

    local first = self.start_tag.end_row
    local last = self.end_tag and self.end_tag.start_row or self.node.end_row
    if self:hide(self.start_tag) then
        first = first + 1
    end
    if self:hide(self.end_tag) then
        last = last - 1
    end

    local lines =
        vim.api.nvim_buf_get_lines(self.context.buf, first, last + 1, false)
    for i, line in ipairs(lines) do
        local row = first + i - 1
        -- the first line starts after the start tag
        local col = row == self.start_tag.end_row and self.start_tag.end_col
            or (line:find('%S') or 1) - 1
        self.marks:add(self.quote, 'quote', row, col, {
            virt_text = { { icon .. ' ', highlight } },
            virt_text_pos = 'inline',
            virt_text_repeat_linebreak = self.quote.repeat_linebreak or nil,
        })
    end
end

return Render
