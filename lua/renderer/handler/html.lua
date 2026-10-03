local Context = require('renderer.request.context')
local Marks = require('renderer.lib.marks')
local ts = require('renderer.core.ts')

---@class renderer.handler.Html: renderer.Handler
local M = {}

---@param ctx renderer.handler.Context
---@return renderer.Mark[]
function M.parse(ctx)
    -- stylua: ignore
    local query = ts.parse('html', [[
        (comment) @comment
        (element) @tag
    ]])
    ---@type table<string, renderer.Render>
    local renders = {
        comment = require('renderer.render.html.comment'),
        tag = require('renderer.render.html.tag'),
    }
    local context = Context.get(ctx.buf)
    if not context.config.html.enabled then
        return {}
    end
    local marks = Marks.new(context, true)
    context.view:nodes(ctx.root, query, function(capture, node)
        local render = renders[capture]
        assert(render, ('unhandled html capture: %s'):format(capture))
        render:execute(context, marks, node)
    end)
    return marks:get()
end

return M
