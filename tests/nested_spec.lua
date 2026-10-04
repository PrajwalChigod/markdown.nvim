---@module 'luassert'

local util = require('tests.util')

describe('nested', function()
    ---@param nested boolean
    local function html(nested)
        util.setup.text(
            { '<b>bold</b>' },
            { file_types = { 'markdown', 'html' }, nested = nested },
            'html'
        )
        local marks = util.marks()
        marks:add({ 0, 0 }, { 0, 3 }, util.conceal())
        marks:add({ 0, 0 }, { 3, 7 }, {
            hl_eol = false,
            hl_group = 'RmHtmlBold',
        })
        marks:add({ 0, 0 }, { 7, 11 }, util.conceal())
        util.assert_view(marks, { 'bold' })
    end

    it('html buffer without nesting', function()
        html(false)
    end)

    it('html buffer with nesting', function()
        html(true)
    end)

    it('markdown in markdown without nesting', function()
        util.setup.text({ '```markdown', '# Heading', '```' }, {
            nested = false,
        })
        -- inner heading is left raw, only the outer code block is rendered
        util.assert_screen({
            '󰍔 󰍔 markdown' .. ('█'):rep(68),
            '  # Heading',
        })
    end)
end)
