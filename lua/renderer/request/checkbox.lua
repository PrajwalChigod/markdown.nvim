---@class renderer.request.checkbox.Value
---@field node renderer.Node
---@field config renderer.checkbox.component.Config

---@class renderer.request.Checkbox
---@field private values table<integer, renderer.request.checkbox.Value>
local Checkbox = {}
Checkbox.__index = Checkbox

---@return renderer.request.Checkbox
function Checkbox.new()
    local self = setmetatable({}, Checkbox)
    self.values = {}
    return self
end

---@param node renderer.Node
---@param config renderer.checkbox.custom.Config
function Checkbox:set(node, config)
    self.values[node.start_row] = {
        node = node,
        config = {
            icon = config.rendered,
            highlight = config.highlight,
            scope_highlight = config.scope_highlight,
        },
    }
end

---@param node renderer.Node
---@return renderer.request.checkbox.Value?
function Checkbox:get(node)
    return self.values[node.start_row]
end

return Checkbox
