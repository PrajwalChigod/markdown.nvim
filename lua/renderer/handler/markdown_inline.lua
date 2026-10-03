local Context = require('renderer.request.context')
local Marks = require('renderer.lib.marks')
local ts = require('renderer.core.ts')

---@class renderer.handler.MarkdownInline: renderer.Handler
local M = {}

---@param ctx renderer.handler.Context
---@return renderer.Mark[]
function M.parse(ctx)
    -- stylua: ignore
    local query = ts.parse('markdown_inline', [[
        (code_span) @code

        ((inline) @highlight
            (#lua-match? @highlight "==[^=]+=="))

        [
            (email_autolink)
            (full_reference_link)
            (image)
            (inline_link)
            (uri_autolink)
        ] @link

        (shortcut_link) @shortcut
    ]])
    ---@type table<string, renderer.Render>
    local renders = {
        code = require('renderer.render.inline.code'),
        highlight = require('renderer.render.inline.highlight'),
        link = require('renderer.render.inline.link'),
        shortcut = require('renderer.render.inline.shortcut'),
    }
    local context = Context.get(ctx.buf)
    local marks = Marks.new(context, true)
    context.view:nodes(ctx.root, query, function(capture, node)
        local render = renders[capture]
        assert(render, ('unhandled inline capture: %s'):format(capture))
        render:execute(context, marks, node)
    end)
    return marks:get()
end

return M
