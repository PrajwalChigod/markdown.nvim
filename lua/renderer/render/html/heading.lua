local Element = require('renderer.render.html.element')
local list = require('renderer.lib.list')

---Adds the heading icon and background to `h1` to `h6`, only in a `.html` file
---as markdown files already style these tags through `html.tag`
---@class renderer.render.html.Heading: renderer.render.html.Element
---@field private heading renderer.heading.Config
---@field private level integer
local Render = setmetatable({}, Element)
Render.__index = Render

---@protected
---@return boolean
function Render:enabled()
    self.heading = self.context.config.heading
    local level = tonumber(self.name:match('^h([1-6])$'))
    if not level or not self.heading.enabled or not self:file() then
        return false
    end
    self.level = level
    return true
end

---@protected
function Render:run()
    local fg = list.clamp(self.heading.foregrounds, self.level)
    local bg = list.clamp(self.heading.backgrounds, self.level)
    local icons = self.heading.icons
    local icon ---@type string?
    if type(icons) == 'function' then
        icon = icons({ level = self.level, sections = { self.level } })
    else
        icon = list.cycle(icons, self.level)
    end
    local highlight = {} ---@type string[]
    highlight[#highlight + 1] = fg
    highlight[#highlight + 1] = bg
    if icon and #highlight > 0 then
        self.marks:start(self.heading, 'head_icon', self.start_tag, {
            virt_text = { { icon, highlight } },
            virt_text_pos = 'inline',
        })
    end
    if bg then
        for row = self.node.start_row, self.node.end_row do
            self.marks:add(self.heading, 'head_background', row, 0, {
                end_row = row + 1,
                hl_group = bg,
                hl_eol = true,
            })
        end
    end
end

return Render
