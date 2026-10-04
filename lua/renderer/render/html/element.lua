local Base = require('renderer.render.base')

---Base for renderers of one HTML element, resolves its tags and name
---@class renderer.render.html.Element: renderer.Render
---@field protected config renderer.html.Config
---@field protected name string lower case tag name
---@field protected start_tag renderer.Node
---@field protected end_tag? renderer.Node
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.html
    local start_tag = Render.start_of(self.node)
    local name = start_tag and start_tag:child('tag_name')
    if not start_tag or not name then
        return false
    end
    self.name = name.text:lower()
    self.start_tag = start_tag
    self.end_tag = self.node:child('end_tag')
    return self:enabled()
end

---@protected
---@return boolean
function Render:enabled()
    return true
end

---@param node renderer.Node
---@return string?
function Render.name_of(node)
    local start_tag = Render.start_of(node)
    local name = start_tag and start_tag:child('tag_name')
    return name and name.text:lower() or nil
end

---@private
---@param node renderer.Node
---@return renderer.Node?
function Render.start_of(node)
    return node:child('start_tag') or node:child('self_closing_tag')
end

---Whether the node is the only thing on its lines
---@protected
---@param node renderer.Node
---@return boolean
function Render:alone(node)
    local buf = self.context.buf
    local function line(row)
        return vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
    end
    return not line(node.start_row):sub(1, node.start_col):find('%S')
        and not line(node.end_row):sub(node.end_col + 1):find('%S')
end

---Hide the lines of a node when it is alone on them, otherwise just the node
---@protected
---@param node? renderer.Node
---@return boolean hidden whether whole lines were hidden
function Render:hide(node)
    if not node then
        return false
    elseif self:alone(node) then
        self.marks:over(self.config, true, node, { conceal_lines = '' })
        return true
    else
        self.marks:over(self.config, true, node, { conceal = '' })
        return false
    end
end

---Whether the buffer is a whole HTML file rather than markdown
---@protected
---@return boolean
function Render:file()
    local format = self.context.format
    return format ~= nil and format.name == 'html'
end

---Whether structure rules apply, only in a `.html` file
---@protected
---@return boolean
function Render:structure()
    return self.config.structure and self:file()
end

return Render
