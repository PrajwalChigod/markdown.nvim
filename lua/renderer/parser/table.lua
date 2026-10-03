local Indent = require('renderer.lib.indent')
local display = require('renderer.lib.display')
local env = require('renderer.lib.env')
local log = require('renderer.core.log')
local str = require('renderer.lib.str')

---@class renderer.table.Data
---@field layout renderer.table.Layout
---@field delim renderer.Node
---@field cols renderer.table.Col[]
---@field rows renderer.table.Row[]
---@field prefixes table<integer, renderer.mark.Line>

---@class renderer.table.Layout
---@field col integer
---@field valid boolean
---@field wrap boolean

---@class renderer.table.Col
---@field width integer
---@field alignment renderer.table.col.Alignment

---@class renderer.table.Row
---@field node renderer.Node
---@field pipes renderer.Node[]
---@field cells renderer.table.row.Cell[]

---@class renderer.table.row.Cell
---@field node renderer.Node
---@field width integer
---@field space renderer.table.cell.Space
---@field units? renderer.table.Unit[]

---@class renderer.table.cell.Space
---@field left integer
---@field right integer

---@class renderer.table.row.Parts
---@field pipes renderer.Node[]
---@field cells renderer.Node[]

---@class renderer.table.Unit
---@field text string
---@field highlight renderer.mark.Hl
---@field width integer

---@class renderer.parser.Table
---@field private context renderer.request.Context
---@field private config renderer.table.Config
local Parser = {}
Parser.__index = Parser

---@enum renderer.table.col.Alignment
Parser.Alignment = {
    left = 'left',
    right = 'right',
    center = 'center',
    default = 'default',
}

---@param context renderer.request.Context
---@param config renderer.table.Config
---@return renderer.parser.Table
function Parser.new(context, config)
    local self = setmetatable({}, Parser)
    self.context = context
    self.config = config
    return self
end

---@param root renderer.Node
---@param marks renderer.Marks
---@return renderer.table.Data?
function Parser:parse(root, marks)
    -- ensure delimiter and rows exist
    local delim = nil ---@type renderer.Node?
    local row_nodes = {} ---@type renderer.Node[]
    local types = {
        delim = 'pipe_table_delimiter_row',
        row = { 'pipe_table_header', 'pipe_table_row' },
        skip = { 'block_continuation' },
    }
    root:for_each_child(function(node)
        if node.type == types.delim then
            delim = node
        elseif self.context.view:overlaps(node:get()) then
            if vim.tbl_contains(types.row, node.type) then
                row_nodes[#row_nodes + 1] = node
            elseif not vim.tbl_contains(types.skip, node.type) then
                log.unhandled(self.context.buf, 'markdown', 'row', node.type)
            end
        end
    end)
    if not delim or #row_nodes == 0 then
        return nil
    end

    ---@type renderer.table.Layout
    local layout = {
        col = delim:col(),
        valid = true,
        wrap = self.config.wrap and self.context.conceal.level > 1,
    }

    local cols = self:cols(delim)
    if not cols then
        return nil
    end

    local rows = {} ---@type renderer.table.Row[]
    table.sort(row_nodes)
    for _, row_node in ipairs(row_nodes) do
        local row = self:row(row_node, #cols)
        if row then
            if row.node:col() ~= layout.col then
                layout.valid = false
                layout.wrap = false
            end
            rows[#rows + 1] = row
        end
    end
    if #rows == 0 then
        return nil
    end

    -- store the max width in cols
    for _, row in ipairs(rows) do
        for i, cell in ipairs(row.cells) do
            local space = cell.space.left + cell.space.right
            local available = space - (2 * self.config.padding)
            -- if we don't have enough space for padding add it to the width
            local width = cell.width
            if available < 0 then
                width = width - available
            end
            if self.config.cell == 'trimmed' then
                width = width - math.max(available, 0)
            end
            cols[i].width = math.max(cols[i].width, width)
        end
    end

    local prefixes = {} ---@type table<integer, renderer.mark.Line>
    if layout.wrap then
        local indent = Indent.new(self.context, root):line(true)
        local prefix_width = 0

        ---@param node renderer.Node
        local function prefix(node)
            local expanded = self.context.config:line()
            local line = indent:copy():extend(
                display.prefix(self.context, marks:get(), node)
            )
            for _, unit in ipairs(Parser.units(line:get())) do
                expanded:text(unit.text, unit.highlight)
            end
            prefixes[node.start_row] = expanded:get()
            prefix_width = math.max(prefix_width, expanded:width())
        end

        local desired = {} ---@type integer[]
        local minimum = {} ---@type integer[]
        local padding = self.config.padding
        for i, col in ipairs(cols) do
            desired[i] = col.width
            minimum[i] = math.max(self.config.min_width, 2 * padding + 1)
        end

        prefix(delim)
        for _, row in ipairs(rows) do
            prefix(row.node)
            for i, cell in ipairs(row.cells) do
                local node = cell.node
                local left = str.spaces('start', node.text)
                local right = str.spaces('end', node.text)
                local line = display.line(self.context, {
                    start_row = node.start_row,
                    end_row = node.end_row,
                    start_col = node.start_col + left,
                    end_col = node.end_col - right,
                    text = node.text:sub(left + 1, #node.text - right),
                })
                cell.units = Parser.units(line)

                local width, smallest = Parser.measure(cell.units)
                desired[i] = math.max(desired[i], 2 * padding + width)
                minimum[i] = math.max(minimum[i], 2 * padding + smallest)
            end
        end

        local budget = env.win.width(self.context.win)
        budget = budget - (prefix_width + #cols + 1)

        local widths = Parser.allocate(desired, minimum, budget)
        if not widths then
            layout.wrap = false
        else
            for i, width in ipairs(widths) do
                cols[i].width = width
            end
        end
    end

    ---@type renderer.table.Data
    return {
        layout = layout,
        delim = delim,
        cols = cols,
        rows = rows,
        prefixes = prefixes,
    }
end

---@private
---@param node renderer.Node
---@return renderer.table.Col[]?
function Parser:cols(node)
    local parts = self:row_parts(node, 'pipe_table_delimiter_cell')
    if not parts then
        return nil
    end
    local cols = {} ---@type renderer.table.Col[]
    for i, cell in ipairs(parts.cells) do
        local start_col = parts.pipes[i].end_col
        local end_col = parts.pipes[i + 1].start_col
        local width = end_col - start_col
        assert(width >= 0, 'invalid table layout')
        if self.config.cell == 'padded' then
            width = math.max(width, self.config.min_width)
        elseif self.config.cell == 'trimmed' then
            width = self.config.min_width
        end
        cols[#cols + 1] = {
            width = width,
            alignment = Parser.alignment(cell),
        }
    end
    return cols
end

---@private
---@param node renderer.Node
---@return renderer.table.col.Alignment
function Parser.alignment(node)
    local left = node:child('pipe_table_align_left')
    local right = node:child('pipe_table_align_right')
    if left and right then
        return Parser.Alignment.center
    elseif left then
        return Parser.Alignment.left
    elseif right then
        return Parser.Alignment.right
    else
        return Parser.Alignment.default
    end
end

---@private
---@param node renderer.Node
---@param num_cols integer
---@return renderer.table.Row?
function Parser:row(node, num_cols)
    local parts = self:row_parts(node, 'pipe_table_cell')
    if not parts or #parts.cells ~= num_cols then
        return nil
    end
    local cells = {} ---@type renderer.table.row.Cell[]
    for i, cell in ipairs(parts.cells) do
        -- account for double width glyphs by replacing cell range with width
        local start_col = parts.pipes[i].end_col
        local end_col = parts.pipes[i + 1].start_col
        local width = (end_col - start_col)
            - (cell.end_col - cell.start_col)
            + self.context:width(cell)
            + self.config.cell_offset({ node = cell:get() })
        assert(width >= 0, 'invalid table layout')
        cells[#cells + 1] = {
            node = cell,
            width = width,
            space = {
                -- gap between the cell start and the pipe start
                left = math.max(cell.start_col - start_col, 0),
                -- attached to the end of the cell itself
                right = math.max(str.spaces('end', cell.text), 0),
            },
        }
    end
    ---@type renderer.table.Row
    return { node = node, pipes = parts.pipes, cells = cells }
end

---@private
---@param node renderer.Node
---@param cell_type string
---@return renderer.table.row.Parts?
function Parser:row_parts(node, cell_type)
    local pipes = {} ---@type renderer.Node[]
    local cells = {} ---@type renderer.Node[]
    node:for_each_child(function(child)
        if child.type == '|' then
            pipes[#pipes + 1] = child
        elseif child.type == cell_type then
            cells[#cells + 1] = child
        else
            log.unhandled(self.context.buf, 'markdown', 'cell', child.type)
        end
    end)
    if #pipes == 0 or #cells == 0 or #pipes ~= #cells + 1 then
        return nil
    end
    table.sort(pipes)
    table.sort(cells)
    ---@type renderer.table.row.Parts
    return { pipes = pipes, cells = cells }
end

---@param line renderer.mark.Line
---@return renderer.table.Unit[]
function Parser.units(line)
    local result = {} ---@type renderer.table.Unit[]
    for _, text in ipairs(line) do
        for _, char in ipairs(str.chars(text[1])) do
            result[#result + 1] = {
                text = char,
                highlight = text[2],
                width = str.width(char),
            }
        end
    end
    return result
end

---@param units renderer.table.Unit[]
---@return integer, integer
function Parser.measure(units)
    local width, minimum = 0, 1
    for _, unit in ipairs(units) do
        width = width + unit.width
        minimum = math.max(minimum, unit.width)
    end
    return width, minimum
end

---@param desired integer[]
---@param minimum integer[]
---@param budget integer
---@return integer[]?
function Parser.allocate(desired, minimum, budget)
    local natural = 0
    local floor = 0
    for i, width in ipairs(desired) do
        natural = natural + width ---@type integer
        floor = floor + minimum[i] ---@type integer
    end
    if natural <= budget then
        return desired
    end
    if budget < floor then
        return nil
    end

    local locked = {} ---@type table<integer, true>
    local free = #desired
    local share = math.floor(budget / free)
    local changed = true
    while changed do
        changed = false
        for i = 1, #desired do
            if not locked[i] and desired[i] <= share then
                locked[i] = true
                budget = budget - desired[i]
                free = free - 1
                changed = true
            end
        end
        share = math.floor(budget / free)
    end

    local widths = {} ---@type integer[]
    for i, width in ipairs(desired) do
        widths[i] = locked[i] and width or share
    end

    -- share any leftover budget arbitrarily
    budget = budget - (free * share)
    for i = 1, budget do
        widths[i] = widths[i] + 1
    end

    return widths
end

---@param units renderer.table.Unit[]
---@param width integer
---@return renderer.mark.Line[]
function Parser.wrap(units, width)
    local result = {} ---@type renderer.mark.Line[]
    local first = 1
    while first <= #units do
        local last = first - 1
        local used = 0
        local space = nil ---@type integer|nil
        while last < #units and used + units[last + 1].width <= width do
            last = last + 1
            used = used + units[last].width
            if str.whitespace(units[last].text) then
                space = last
            end
        end
        assert(last >= first, 'table unit exceeds column width')
        local next_unit = last + 1
        if
            last < #units
            and not str.whitespace(units[last + 1].text)
            and space
            and space > first
        then
            last = space - 1
            next_unit = space + 1
        end
        local line = {} ---@type renderer.mark.Line
        for i = first, last do
            local unit = units[i]
            local previous = line[#line]
            if previous and vim.deep_equal(previous[2], unit.highlight) then
                previous[1] = previous[1] .. unit.text
            else
                line[#line + 1] = { unit.text, unit.highlight }
            end
        end
        result[#result + 1] = line
        first = next_unit
        while first <= #units and str.whitespace(units[first].text) do
            first = first + 1 ---@type integer
        end
    end
    return #result > 0 and result or { {} }
end

---@param line renderer.mark.Line
---@param width integer
---@param alignment renderer.table.col.Alignment
---@param padding integer
---@param highlight string
---@return renderer.mark.Line
function Parser.align(line, width, alignment, padding, highlight)
    local extra = width - 2 * padding - str.line_width(line)
    local left = alignment == Parser.Alignment.right and extra
        or alignment == Parser.Alignment.center and math.floor(extra / 2)
        or 0
    local result = { { str.pad(padding + left), highlight } }
    vim.list_extend(result, line)
    result[#result + 1] = { str.pad(padding + extra - left), highlight }
    return result
end

return Parser
