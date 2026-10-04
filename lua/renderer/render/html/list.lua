local Element = require('renderer.render.html.element')
local list = require('renderer.lib.list')

---Hides the `ul` and `ol` tags and replaces the `li` tag with a bullet
---@class renderer.render.html.List: renderer.render.html.Element
---@field private bullet renderer.bullet.Config
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    self.bullet = self.context.config.bullet
    return self.config.list and self.bullet.enabled
end

---@protected
function Render:run()
    if self.name == 'li' then
        self:item()
    else
        self:hide(self.start_tag)
        self:hide(self.end_tag)
    end
end

---@private
function Render:item()
    local hidden = self:hide(self.start_tag)
    self:hide(self.end_tag)

    local row, col = self.start_tag.start_row, self.start_tag.start_col
    if hidden then
        -- the bullet goes on the first line of content
        row = self.start_tag.end_row + 1
        local line = vim.api.nvim_buf_get_lines(
            self.context.buf,
            row,
            row + 1,
            false
        )[1] or ''
        col = (line:find('%S') or 1) - 1
        if self.end_tag and row >= self.end_tag.start_row then
            return
        end
    end

    local level, index, ordered = self:position()
    ---@type renderer.bullet.Context
    local ctx = {
        level = level,
        index = index,
        value = ordered and ('%d.'):format(index) or '-',
    }
    local icons = ordered and self.bullet.ordered_icons or self.bullet.icons
    local icon = Render.get_string(icons, ctx)
    local highlight = Render.get_string(self.bullet.highlight, ctx)
    if not icon or not highlight then
        return
    end
    self.marks:add(self.bullet, 'bullet', row, col, {
        virt_text = { { icon .. ' ', highlight } },
        virt_text_pos = 'inline',
    })
end

---Nesting level, index among the siblings and whether the list is ordered
---@private
---@return integer, integer, boolean
function Render:position()
    local level = 0
    local ordered = false
    local container = self.node:parent('element')
    while container do
        local name = Element.name_of(container)
        if name == 'ul' or name == 'ol' then
            if level == 0 then
                ordered = name == 'ol'
            end
            level = level + 1
        end
        container = container:parent('element')
    end

    local index = self:index()
    return math.max(level, 1), index, ordered
end

---Position of the item among the items of its list, 1-indexed
---@private
---@return integer
function Render:index()
    local index = 0
    local target = self.node:get()
    local parent = assert(target:parent(), 'item without parent')
    for child in parent:iter_children() do
        local tag = child:type() == 'element' and child:child(0)
        local name = tag and tag:named_child(0)
        if name and name:type() == 'tag_name' then
            local text = vim.treesitter.get_node_text(name, self.context.buf)
            index = index + (text:lower() == 'li' and 1 or 0)
        end
        if child:id() == target:id() then
            break
        end
    end
    return index
end

---Same evaluation as the markdown bullet
---@private
---@param values renderer.bullet.String
---@param ctx renderer.bullet.Context
---@return string?
function Render.get_string(values, ctx)
    if type(values) == 'function' then
        return values(ctx)
    else
        local value = list.cycle(values, ctx.level)
        return list.clamp(value, ctx.index)
    end
end

return Render
