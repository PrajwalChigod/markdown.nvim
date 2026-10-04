local Context = require('renderer.request.context')
local Element = require('renderer.render.html.element')
local Marks = require('renderer.lib.marks')
local ts = require('renderer.core.ts')

---Renderers for specific elements, run after the generic tag renderer
---@type table<string, string>
local elements = {
    html = 'page',
    body = 'page',
    head = 'head',
    ul = 'list',
    ol = 'list',
    li = 'list',
    blockquote = 'quote',
    pre = 'pre',
    hr = 'rule',
    a = 'link',
    h1 = 'heading',
    h2 = 'heading',
    h3 = 'heading',
    h4 = 'heading',
    h5 = 'heading',
    h6 = 'heading',
}

---@class renderer.handler.Html: renderer.Handler
local M = {}

---@param ctx renderer.handler.Context
---@return renderer.Mark[]
function M.parse(ctx)
    -- stylua: ignore
    local query = ts.parse('html', [[
        (comment) @comment
        (element) @tag
        (doctype) @doctype
        (entity) @entity
        (script_element) @raw
        (style_element) @raw
    ]])
    ---@type table<string, renderer.Render>
    local renders = {
        comment = require('renderer.render.html.comment'),
        tag = require('renderer.render.html.tag'),
        doctype = require('renderer.render.html.doctype'),
        entity = require('renderer.render.html.entity'),
        raw = require('renderer.render.html.raw'),
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
        if capture == 'tag' then
            local name = elements[Element.name_of(node) or '']
            if name then
                require('renderer.render.html.' .. name):execute(
                    context,
                    marks,
                    node
                )
            end
        end
    end)
    return marks:get()
end

return M
