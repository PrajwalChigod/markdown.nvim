local Base = require('renderer.render.base')
local list = require('renderer.lib.list')

---@class renderer.yaml.bullet.Data
---@field icon? string
---@field highlight? string

---@class renderer.render.yaml.Bullet: renderer.Render
---@field private config renderer.bullet.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.bullet
    return self.config.enabled
end

---@protected
function Render:run()
    ---@type renderer.bullet.Context
    local ctx = {
        level = self.node:level_in('block_sequence'),
        index = self.node:sibling_count('block_sequence_item'),
        value = '-',
    }
    local icon = Render.get_string(self.config.icons, ctx)
    local highlight = Render.get_string(self.config.highlight, ctx)
    if not icon or not highlight then
        return
    end
    self.marks:start(self.config, 'bullet', self.node, {
        virt_text = { { icon, highlight } },
        virt_text_pos = 'overlay',
    })
end

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
