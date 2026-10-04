local str = require('renderer.lib.str')

---@class renderer.request.Context
---@field buf integer
---@field win integer
---@field config renderer.buf.Config
---@field format? renderer.Format
---@field view renderer.request.View
---@field callout renderer.request.Callout
---@field checkbox renderer.request.Checkbox
---@field conceal renderer.request.Conceal
---@field highlights renderer.request.Highlights
---@field inline renderer.request.Inline
---@field latex renderer.request.Latex
---@field used renderer.request.Used
local Context = {}
Context.__index = Context

---@param buf integer
---@param win integer
---@param config renderer.buf.Config
---@param view renderer.request.View
---@return renderer.request.Context
function Context.new(buf, win, config, view)
    local self = setmetatable({}, Context)
    self.buf = buf
    self.win = win
    self.config = config
    self.format = require('renderer.format').get(buf)
    self.view = view
    self.callout = require('renderer.request.callout').new()
    self.checkbox = require('renderer.request.checkbox').new()
    self.conceal = require('renderer.request.conceal').new(self)
    self.highlights = require('renderer.request.highlights').new(buf, view)
    self.inline = require('renderer.request.inline').new()
    self.latex = require('renderer.request.latex').new()
    self.used = require('renderer.request.used').new()
    return self
end

---@param body? renderer.node.Body
---@return integer
function Context:width(body)
    if not body then
        return 0
    end
    return str.width(body.text)
        + self.inline:width(body)
        - self.conceal:get(body)
end

---@class renderer.request.context.Manager
local M = {}

---@private
---@type table<integer, renderer.request.Context>
M.cache = {}

---@param buf integer
---@param win integer
---@return boolean
function M.contains(buf, win)
    local context = M.cache[buf]
    return context and context.view:contains(win) or false
end

---@param buf integer
---@param win integer
---@param config renderer.buf.Config
---@return renderer.request.Context?
function M.new(buf, win, config)
    local view = require('renderer.request.view').new(buf)
    local context = Context.new(buf, win, config, view)
    M.cache[buf] = context
    return context
end

---@param buf integer
---@return renderer.request.Context
function M.get(buf)
    return assert(M.cache[buf], 'missing request context')
end

return M
