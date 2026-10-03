---@class renderer.request.callout.Value
---@field node renderer.Node
---@field config renderer.callout.Config

---@class renderer.request.Callout
---@field private values table<integer, renderer.request.callout.Value>
local Callout = {}
Callout.__index = Callout

---@return renderer.request.Callout
function Callout.new()
    local self = setmetatable({}, Callout)
    self.values = {}
    return self
end

---@param node renderer.Node
---@param config renderer.callout.Config
function Callout:set(node, config)
    self.values[node.start_row] = { node = node, config = config }
end

---@param node renderer.Node
---@return renderer.request.callout.Value?
function Callout:get(node)
    return self.values[node.start_row]
end

return Callout
