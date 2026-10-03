local interval = require('renderer.lib.interval')

---@class renderer.request.highlights.Line
---@field hidden boolean
---@field conceals renderer.request.highlights.Conceal[]
---@field groups renderer.request.highlights.Group[]

---@class renderer.request.highlights.Entry
---@field hidden? boolean
---@field conceal? renderer.request.highlights.Conceal
---@field group? renderer.request.highlights.Group

---@class renderer.request.highlights.Conceal: renderer.Range
---@field replacement string
---@field blocks integer

---@class renderer.request.highlights.Group: renderer.Range
---@field priority integer
---@field highlight renderer.mark.Hl

---@class renderer.request.Highlights
---@field private buf integer
---@field private view renderer.request.View
---@field private computed boolean
---@field private lines table<integer, renderer.request.highlights.Line>
local Highlights = {}
Highlights.__index = Highlights

---@param buf integer
---@param view renderer.request.View
---@return renderer.request.Highlights
function Highlights.new(buf, view)
    local self = setmetatable({}, Highlights)
    self.buf = buf
    self.view = view
    self.computed = false
    self.lines = {}
    return self
end

---@param row integer
---@param entry renderer.request.highlights.Entry
function Highlights:add(row, entry)
    if not self.lines[row] then
        self.lines[row] = { hidden = false, conceals = {}, groups = {} }
    end
    local line = self.lines[row]
    if entry.hidden then
        line.hidden = entry.hidden
    end
    if entry.conceal then
        if interval.valid(entry.conceal, true) then
            line.conceals[#line.conceals + 1] = entry.conceal
            line.conceals = Highlights.coalesce_conceals(line.conceals)
        end
    end
    if entry.group then
        if interval.valid(entry.group, true) then
            line.groups[#line.groups + 1] = entry.group
            table.sort(line.groups, function(a, b)
                if a.priority ~= b.priority then
                    return a.priority < b.priority
                else
                    return a.highlight < b.highlight
                end
            end)
        end
    end
end

---@private
---@param conceals renderer.request.highlights.Conceal[]
---@return renderer.request.highlights.Conceal[]
function Highlights.coalesce_conceals(conceals)
    interval.sort(conceals)
    local result = {} ---@type renderer.request.highlights.Conceal[]
    result[#result + 1] = conceals[1]
    for i = 2, #conceals do
        local conceal, last = conceals[i], result[#result]
        if conceal[1] <= last[2] then
            last[2] = math.max(last[2], conceal[2])
            last.replacement = last.replacement .. conceal.replacement
            last.blocks = last.blocks + conceal.blocks
        else
            result[#result + 1] = conceal
        end
    end
    return result
end

---@param row integer
---@return renderer.request.highlights.Line
function Highlights:line(row)
    if not self.computed then
        self.computed = true
        self:compute()
    end
    local line = self.lines[row]
    if not line then
        line = { hidden = false, conceals = {}, groups = {} }
    end
    return line
end

---Cached row level implementation of vim.treesitter.get_captures_at_pos
---@private
function Highlights:compute()
    if not vim.treesitter.highlighter.active[self.buf] then
        return
    end
    local parser = vim.treesitter.get_parser(self.buf)
    if not parser then
        return
    end
    parser:for_each_tree(function(tree, language_tree)
        self:tree(language_tree:lang(), tree:root())
    end)
end

---@private
---@param language string
---@param root TSNode
function Highlights:tree(language, root)
    if not self.view:overlaps(root) then
        return
    end
    if not vim.tbl_contains({ 'markdown', 'markdown_inline' }, language) then
        return
    end
    local query = vim.treesitter.query.get(language, 'highlights')
    if not query then
        return
    end
    self.view:query(root, query, function(id, node, data)
        local row, start_col, _, end_col =
            Highlights.range(self.buf, node, data[id])
        if data.conceal_lines then
            self:add(row, { hidden = true })
        end
        if data.conceal then
            self:add(row, {
                conceal = {
                    start_col,
                    end_col,
                    replacement = data.conceal,
                    blocks = 1,
                },
            })
        end
        self:add(row, {
            group = {
                start_col,
                end_col,
                priority = Highlights.priority(id, data),
                highlight = '@' .. query.captures[id] .. '.' .. language,
            },
        })
    end)
end

---@private
---@param buf integer
---@param node TSNode
---@param metadata? vim.treesitter.query.TSMetadata
---@return integer, integer, integer, integer
function Highlights.range(buf, node, metadata)
    -- applies range & offset! directives
    local range = vim.treesitter.get_range(node, buf, metadata)
    return range[1], range[2], range[4], range[5]
end

---@private
---@param id integer
---@param data vim.treesitter.query.TSMetadata
---@return integer
function Highlights.priority(id, data)
    return tonumber((data[id] or {}).priority or data.priority) or 100
end

return Highlights
