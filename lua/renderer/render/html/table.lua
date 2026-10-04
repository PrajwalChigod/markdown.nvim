local Element = require('renderer.render.html.element')
local Parser = require('renderer.parser.table')
local display = require('renderer.lib.display')
local env = require('renderer.lib.env')
local str = require('renderer.lib.str')

---@class renderer.html.table.Cell
---@field units renderer.table.Unit[]
---@field alignment renderer.table.col.Alignment

---@class renderer.html.table.Row
---@field head boolean
---@field cells renderer.html.table.Cell[]

---@class renderer.html.table.Data
---@field caption? renderer.table.Unit[]
---@field rows renderer.html.table.Row[]
---@field cols integer

---Replaces a `table` with virtual lines drawn from the `pipe_table` config.
---The source lines are hidden, so cells can span lines and nest other tags.
---Tables that cannot be drawn, like those with spans, are left as source.
---@class renderer.render.html.Table: renderer.render.html.Element
---@field private pipe renderer.table.Config
---@field private data renderer.html.table.Data
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    self.pipe = self.context.config.pipe_table
    if not self.config.table or not self.pipe.enabled then
        return false
    end
    -- Cell text comes from the marks of the tags inside, which only exist for
    -- rows in the view, so the whole table has to be in it.
    if not self.end_tag or not self:replaceable(self.node) then
        return false
    end
    if not self.context.view:covers(self.node:get()) then
        return false
    end
    local data = self:parse()
    if not data then
        return false
    end
    self.data = data
    return true
end

---@private
---@return renderer.html.table.Data?
function Render:parse()
    ---@type renderer.html.table.Data
    local data = { rows = {}, cols = 0 }
    if not self:collect(self.node, false, data) or #data.rows == 0 then
        return nil
    end
    return data
end

---@private
---@param node renderer.Node
---@param head boolean
---@param data renderer.html.table.Data
---@return boolean valid
function Render:collect(node, head, data)
    local valid = true
    node:for_each_child(function(child)
        if not valid or child.type ~= 'element' then
            return
        end
        local name = Element.name_of(child)
        if name == 'tr' then
            local row = self:row(child, head)
            valid = row ~= nil
            if row then
                data.rows[#data.rows + 1] = row
                data.cols = math.max(data.cols, #row.cells)
            end
        elseif name == 'thead' then
            valid = self:collect(child, true, data)
        elseif name == 'tbody' or name == 'tfoot' then
            valid = self:collect(child, false, data)
        elseif name == 'caption' then
            data.caption = self:content(child)
        end
    end)
    return valid
end

---@private
---@param node renderer.Node
---@param head boolean
---@return renderer.html.table.Row?
function Render:row(node, head)
    local cells = {} ---@type renderer.html.table.Cell[]
    local headings = true
    local valid = true
    node:for_each_child(function(child)
        if not valid or child.type ~= 'element' then
            return
        end
        local name = Element.name_of(child)
        local cell = (name == 'th' or name == 'td') and self:cell(child)
        valid = cell and true or false
        if cell then
            cells[#cells + 1] = cell
            headings = headings and name == 'th'
        end
    end)
    if not valid or #cells == 0 then
        return nil
    end
    return { head = head or headings, cells = cells }
end

---@private
---@param node renderer.Node
---@return renderer.html.table.Cell?
function Render:cell(node)
    local start_tag = node:child('start_tag')
    if not start_tag or Render.spans(start_tag.text) or Render.nested(node) then
        return nil
    end
    local align = Element.attribute(start_tag.text, 'align')
    local alignment = Parser.Alignment.default
    if align == 'left' or align == 'right' or align == 'center' then
        alignment = Parser.Alignment[align]
    end
    return { units = self:content(node), alignment = alignment }
end

---Cells that span rows or columns do not fit a grid
---@private
---@param text string
---@return boolean
function Render.spans(text)
    for _, name in ipairs({ 'colspan', 'rowspan' }) do
        local value = tonumber(Element.attribute(text, name))
        if value and value > 1 then
            return true
        end
    end
    return false
end

---@private
---@param node renderer.Node
---@return boolean
function Render.nested(node)
    local found = false
    node:for_each_child(function(child)
        if child.type == 'element' then
            found = found
                or Element.name_of(child) == 'table'
                or Render.nested(child)
        end
    end)
    return found
end

---Text between the tags of an element as it appears with all marks applied
---@private
---@param node renderer.Node
---@return renderer.table.Unit[]
function Render:content(node)
    local start_tag = assert(node:child('start_tag'), 'missing start tag')
    local end_tag = node:child('end_tag')
    local first = start_tag.end_row
    local last_row = end_tag and end_tag.start_row or node.end_row
    local last_col = end_tag and end_tag.start_col or node.end_col

    local units = {} ---@type renderer.table.Unit[]
    local lines =
        vim.api.nvim_buf_get_lines(self.context.buf, first, last_row + 1, false)
    for i, line in ipairs(lines) do
        local row = first + i - 1
        local start_col = row == first and start_tag.end_col or 0
        local end_col = row == last_row and last_col or #line
        if end_col > start_col then
            local line_units = Parser.units(display.line(self.context, {
                start_row = row,
                end_row = row,
                start_col = start_col,
                end_col = end_col,
                text = line:sub(start_col + 1, end_col),
            }))
            vim.list_extend(units, line_units)
        end
        -- a line break in the source is a space on screen
        units[#units + 1] = { text = ' ', highlight = '', width = 1 }
    end
    return Render.collapse(units)
end

---Collapse whitespace the way a browser does
---@private
---@param units renderer.table.Unit[]
---@return renderer.table.Unit[]
function Render.collapse(units)
    local result = {} ---@type renderer.table.Unit[]
    local space = nil ---@type renderer.table.Unit?
    for _, unit in ipairs(units) do
        if str.whitespace(unit.text) then
            space = space or unit
        else
            if space and #result > 0 then
                result[#result + 1] = {
                    text = ' ',
                    highlight = space.highlight,
                    width = 1,
                }
            end
            space = nil
            result[#result + 1] = unit
        end
    end
    return result
end

---@protected
function Render:run()
    local prefix = self.node.start_col
    local widths = self:widths(prefix)

    local rows = self.data.rows
    local head = 0 -- leading rows that make up the header
    while head < #rows and rows[head + 1].head do
        head = head + 1
    end

    local lines = {} ---@type renderer.mark.Line[]
    if self.data.caption then
        local width = env.win.width(self.context.win) - prefix
        for _, line in ipairs(Parser.wrap(self.data.caption, width)) do
            lines[#lines + 1] = self:line():pad(prefix):extend(line):get()
        end
    end
    if self.pipe.border_enabled then
        local highlight = head > 0 and self.pipe.head or self.pipe.row
        lines[#lines + 1] = self:border(widths, prefix, 1, highlight)
    end
    for i, row in ipairs(rows) do
        vim.list_extend(lines, self:row_lines(row, widths, prefix))
        if i == head and i < #rows then
            lines[#lines + 1] = self:border(widths, prefix, 4, self.pipe.head)
        end
    end
    if self.pipe.border_enabled then
        lines[#lines + 1] = self:border(widths, prefix, 7, self.pipe.row)
    end
    self.marks:replace(self.config, self.node, lines)
end

---Width of each column, shrunk to fit the window when wrapping is on
---@private
---@param prefix integer
---@return integer[]
function Render:widths(prefix)
    local padding = self.pipe.padding
    local desired = {} ---@type integer[]
    local minimum = {} ---@type integer[]
    for i = 1, self.data.cols do
        desired[i] = math.max(self.pipe.min_width, 2 * padding)
        minimum[i] = math.max(self.pipe.min_width, 2 * padding + 1)
    end
    for _, row in ipairs(self.data.rows) do
        for i, cell in ipairs(row.cells) do
            local width, smallest = Parser.measure(cell.units)
            desired[i] = math.max(desired[i], 2 * padding + width)
            minimum[i] = math.max(minimum[i], 2 * padding + smallest)
        end
    end
    if not self.pipe.wrap then
        return desired
    end
    local budget = env.win.width(self.context.win) - (prefix + #desired + 1)
    local widths = Parser.allocate(desired, minimum, budget)
    for i, width in ipairs(widths or {}) do
        if width < minimum[i] then
            return desired
        end
    end
    return widths or desired
end

---A line of the table border, `index` is the first of three characters
---@private
---@param widths integer[]
---@param prefix integer
---@param index integer
---@param highlight string
---@return renderer.mark.Line
function Render:border(widths, prefix, index, highlight)
    local border = self.pipe.border
    local parts = vim.tbl_map(function(width)
        return border[11]:rep(width)
    end, widths)
    local text = border[index]
        .. table.concat(parts, border[index + 1])
        .. border[index + 2]
    return self:line():pad(prefix):text(text, highlight):get()
end

---@private
---@param row renderer.html.table.Row
---@param widths integer[]
---@param prefix integer
---@return renderer.mark.Line[]
function Render:row_lines(row, widths, prefix)
    local padding = self.pipe.padding
    local icon = self.pipe.border[10]
    local highlight = row.head and self.pipe.head or self.pipe.row

    local cells = {} ---@type renderer.mark.Line[][]
    local height = 1
    for i, width in ipairs(widths) do
        local cell = row.cells[i]
        cells[i] = Parser.wrap(cell and cell.units or {}, width - 2 * padding)
        height = math.max(height, #cells[i])
    end

    local lines = {} ---@type renderer.mark.Line[]
    for fragment = 1, height do
        local line = self:line():pad(prefix):text(icon, highlight)
        for i, width in ipairs(widths) do
            local cell = row.cells[i]
            local alignment = cell and cell.alignment
                or Parser.Alignment.default
            line:extend(
                Parser.align(
                    cells[i][fragment] or {},
                    width,
                    alignment,
                    padding,
                    highlight
                )
            )
            line:text(icon, highlight)
        end
        lines[#lines + 1] = line:get()
    end
    return lines
end

return Render
