local Base = require('render-markdown.render.base')
local Tag = require('render-markdown.render.html.tag')

---@class render.md.render.inline.Html: render.md.Render
---@field private config render.md.html.Config
local Render = setmetatable({}, Base)
Render.__index = Render

---@protected
---@return boolean
function Render:setup()
    self.config = self.context.config.html
    return self.config.enabled
end

---Pairs up inline start and end tags, e.g. `<b>text</b>`
---@protected
function Render:run()
    ---@type { name: string, node: render.md.Node }[]
    local open = {}
    self.node:for_each_child(function(child)
        if child.type ~= 'html_tag' then
            return
        end
        local slash, name = child.text:match('^<(/?)([%w-]+)')
        if not name then
            return
        end
        name = name:lower()
        if slash == '/' then
            for i = #open, 1, -1 do
                if open[i].name == name then
                    local start_tag = open[i].node
                    for j = #open, i, -1 do
                        open[j] = nil
                    end
                    Tag.apply(self.config, self.marks, name, start_tag, child)
                    break
                end
            end
        elseif Tag.is_void(name) or child.text:find('/>$') then
            Tag.apply(self.config, self.marks, name, child)
        else
            open[#open + 1] = { name = name, node = child }
        end
    end)
end

return Render
