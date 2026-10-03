---@class renderer.request.Latex
---@field private nodes renderer.Node[]
local Latex = {}
Latex.__index = Latex

---@return renderer.request.Latex
function Latex.new()
    local self = setmetatable({}, Latex)
    self.nodes = {}
    return self
end

---@param node renderer.Node
function Latex:add(node)
    self.nodes[#self.nodes + 1] = node
end

---@return renderer.Node[]
function Latex:get()
    return self.nodes
end

return Latex
