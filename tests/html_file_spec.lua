---@module 'luassert'

local util = require('tests.util')

---@param lines string[]
---@param opts? renderer.UserConfig
---@param filetype? string
local function setup(lines, opts, filetype)
    local config = { file_types = { 'markdown', 'html' } }
    config = vim.tbl_deep_extend('force', config, opts or {})
    util.setup.text(lines, config, filetype or 'html')
end

---@param marks renderer.test.Marks
---@param row renderer.test.Range|integer
---@param col renderer.test.Range
local function hide(marks, row, col)
    marks:add(row, col, util.conceal_lines())
end

---@param marks renderer.test.Marks
---@param row integer
---@param col integer
---@param text string
---@param highlight? string
local function inline(marks, row, col, text, highlight)
    marks:add(row, col, {
        virt_text = { { text, highlight or 'RmBullet' } },
        virt_text_pos = 'inline',
    })
end

describe('html file', function()
    it('hides doctype, html and body on their own lines', function()
        setup({
            '<!DOCTYPE html>',
            '<html>',
            '<body>',
            'x',
            '</body>',
            '</html>',
        })
        local marks = util.marks()
        hide(marks, { 0, 0 }, { 0, 15 })
        hide(marks, { 1, 1 }, { 0, 6 })
        hide(marks, { 2, 2 }, { 0, 6 })
        hide(marks, { 4, 4 }, { 0, 7 })
        hide(marks, { 5, 5 }, { 0, 7 })
        util.assert_view(marks, { 'x' })
    end)

    it('head shows only the title', function()
        setup({
            '<html>',
            '<head>',
            '  <title>My Page</title>',
            '  <meta charset="utf-8">',
            '</head>',
            '<body>x</body>',
            '</html>',
        })
        local marks = util.marks()
        hide(marks, { 0, 0 }, { 0, 6 })
        hide(marks, { 1, 4 }, { 0, 7 })
        marks:add(5, 0, {
            virt_lines = { { { 'My Page', 'RmHtmlBold' } } },
            virt_lines_above = true,
        })
        marks:add({ 5, 5 }, { 0, 6 }, util.conceal())
        marks:add({ 5, 5 }, { 7, 14 }, util.conceal())
        hide(marks, { 6, 6 }, { 0, 7 })
        util.assert_view(marks, { 'My Page', 'x' })
    end)

    it('head without a title is hidden', function()
        setup({ '<head>', '  <meta charset="utf-8">', '</head>', 'x' })
        local marks = util.marks()
        hide(marks, { 0, 2 }, { 0, 7 })
        util.assert_view(marks, { 'x' })
    end)

    it('collapses style and script', function()
        setup({
            'a',
            '<style>',
            '  p { color: red }',
            '</style>',
            '<script>',
            'x()',
            'y()',
            '</script>',
            'b',
        })
        local marks = util.marks()
        hide(marks, { 1, 3 }, { 0, 8 })
        hide(marks, { 4, 7 }, { 0, 9 })
        marks:add(8, 0, {
            virt_lines = {
                { { '󰌜 style (3 lines)', 'RmHtmlComment' } },
                { { '󰌞 script (4 lines)', 'RmHtmlComment' } },
            },
            virt_lines_above = true,
        })
        util.assert_view(
            marks,
            { 'a', '󰌜 style (3 lines)', '󰌞 script (4 lines)', 'b' }
        )
    end)

    it('style and script inside head are not summarized twice', function()
        setup({ '<head>', '<style>', 'p {}', '</style>', '</head>', 'x' })
        local marks = util.marks()
        hide(marks, { 0, 4 }, { 0, 7 })
        util.assert_view(marks, { 'x' })
    end)

    it('bullets for ul and li', function()
        setup({ '<ul>', '  <li>one</li>', '  <li>two</li>', '</ul>' })
        local marks = util.marks()
        hide(marks, { 0, 0 }, { 0, 4 })
        for row, text in ipairs({ 'one', 'two' }) do
            inline(marks, row, 2, '● ')
            marks:add({ row, row }, { 2, 6 }, util.conceal())
            marks:add({ row, row }, { 6 + #text, 11 + #text }, util.conceal())
        end
        hide(marks, { 3, 3 }, { 0, 5 })
        util.assert_view(marks, { '  ● one', '  ● two' })
    end)

    it('nested lists use the next bullet icon', function()
        setup({
            '<ul>',
            '  <li>one</li>',
            '  <li>two',
            '    <ul>',
            '      <li>deep</li>',
            '    </ul>',
            '  </li>',
            '</ul>',
        })
        local marks = util.marks()
        hide(marks, { 0, 0 }, { 0, 4 })
        inline(marks, 1, 2, '● ')
        marks:add({ 1, 1 }, { 2, 6 }, util.conceal())
        marks:add({ 1, 1 }, { 9, 14 }, util.conceal())
        inline(marks, 2, 2, '● ')
        marks:add({ 2, 2 }, { 2, 6 }, util.conceal())
        hide(marks, { 3, 3 }, { 4, 8 })
        inline(marks, 4, 6, '○ ')
        marks:add({ 4, 4 }, { 6, 10 }, util.conceal())
        marks:add({ 4, 4 }, { 14, 19 }, util.conceal())
        hide(marks, { 5, 5 }, { 4, 9 })
        hide(marks, { 6, 6 }, { 2, 7 })
        hide(marks, { 7, 7 }, { 0, 5 })
        util.assert_view(marks, { '  ● one', '  ● two', '      ○ deep' })
    end)

    it('numbers items of ol', function()
        setup({
            '<ol>',
            '  <li>a</li>',
            '  <li>b</li>',
            '  <li>c</li>',
            '</ol>',
        })
        local marks = util.marks()
        hide(marks, { 0, 0 }, { 0, 4 })
        for row, number in ipairs({ '1. ', '2. ', '3. ' }) do
            inline(marks, row, 2, number)
            marks:add({ row, row }, { 2, 6 }, util.conceal())
            marks:add({ row, row }, { 7, 12 }, util.conceal())
        end
        hide(marks, { 4, 4 }, { 0, 5 })
        util.assert_view(marks, { '  1. a', '  2. b', '  3. c' })
    end)

    it('hr', function()
        setup({ '<hr>' })
        local marks = util.marks()
        marks:add(0, 0, {
            virt_text = { { ('─'):rep(vim.o.columns), 'RmDash' } },
            virt_text_pos = 'overlay',
        })
        util.assert_view(marks, { ('─'):rep(vim.o.columns) })
    end)

    it('blockquote', function()
        setup({ '<blockquote>', '  quoted', '  more', '</blockquote>' })
        local marks = util.marks()
        hide(marks, { 0, 0 }, { 0, 12 })
        inline(marks, 1, 2, '▋ ', 'RmQuote1')
        inline(marks, 2, 2, '▋ ', 'RmQuote1')
        hide(marks, { 3, 3 }, { 0, 13 })
        util.assert_view(marks, { '  ▋ quoted', '  ▋ more' })
    end)

    it('pre', function()
        setup({ '<pre>', 'code', '</pre>' })
        local marks = util.marks()
        for row = 0, 2 do
            marks:add({ row, row + 1 }, { 0, 0 }, {
                hl_eol = true,
                hl_group = 'RmCode',
                priority = 140,
            })
        end
        util.assert_view(marks, { '<pre>', 'code', '</pre>' })
    end)

    it('h2', function()
        setup({ '<h2>Title</h2>' })
        local marks = util.marks()
        marks:add(0, 0, {
            virt_text = { { '󰲣 ', 'RmH2:RmH2Bg' } },
            virt_text_pos = 'inline',
        })
        marks:add({ 0, 0 }, { 0, 4 }, util.conceal())
        marks:add({ 0, 0 }, { 4, 9 }, { hl_eol = false, hl_group = 'RmH2' })
        marks:add({ 0, 0 }, { 9, 14 }, util.conceal())
        marks:add({ 0, 1 }, { 0, 0 }, { hl_eol = true, hl_group = 'RmH2Bg' })
        util.assert_view(marks, { '󰲣 Title' })
    end)

    it('entities', function()
        setup({ '<p>a &amp; b &lt; &nbsp;&#169; &#xA9; &bogus;</p>' })
        local marks = util.marks()
        marks:add({ 0, 0 }, { 0, 3 }, util.conceal())
        local entities = {
            { 5, 10, '&' },
            { 13, 17, '<' },
            { 18, 24, ' ' },
            { 24, 30, '©' },
            { 31, 37, '©' },
        }
        for _, entity in ipairs(entities) do
            marks:add(0, entity[1], {
                hl_mode = 'combine',
                virt_text = { { entity[3], '' } },
                virt_text_pos = 'inline',
            })
            marks:add({ 0, 0 }, { entity[1], entity[2] }, util.conceal())
        end
        marks:add({ 0, 0 }, { 45, 49 }, util.conceal())
        util.assert_view(marks, { 'a & b <  © © &bogus;' })
    end)

    it('anchor with href', function()
        setup({ '<a href="x">link</a>' })
        local marks = util.marks()
        marks:add(0, 0, {
            virt_text = { { '󰌹 ', 'RmLink' } },
            virt_text_pos = 'inline',
        })
        marks:add({ 0, 0 }, { 0, 12 }, util.conceal())
        marks:add({ 0, 0 }, { 12, 16 }, { hl_eol = false, hl_group = 'RmLink' })
        marks:add({ 0, 0 }, { 16, 20 }, util.conceal())
        util.assert_view(marks, { '󰌹 link' })
    end)

    describe('switches', function()
        ---@param lines string[]
        ---@param key string
        local function raw(lines, key)
            setup(lines, { html = { [key] = false } })
            util.assert_view(util.marks(), lines)
        end

        it('structure', function()
            raw(
                { '<!DOCTYPE html>', '<html>', '<head>', '</head>', '</html>' },
                'structure'
            )
        end)

        it('list', function()
            raw({ '<ul>', '  <li>one</li>', '</ul>' }, 'list')
        end)

        it('quote', function()
            raw({ '<blockquote>', '  quoted', '</blockquote>' }, 'quote')
        end)

        it('pre', function()
            raw({ '<pre>', 'code', '</pre>' }, 'pre')
        end)

        it('rule', function()
            raw({ '<hr>' }, 'rule')
        end)

        it('entity', function()
            raw({ 'a &amp; b' }, 'entity')
        end)
    end)

    it('disabled renders nothing', function()
        local lines = {
            '<!DOCTYPE html>',
            '<ul>',
            '  <li>one &amp; two</li>',
            '</ul>',
            '<hr>',
        }
        setup(lines, { html = { enabled = false } })
        util.assert_view(util.marks(), lines)
    end)

    it('markdown keeps html and body lines', function()
        local lines = { '<html>', '<body>', 'text', '</body>', '</html>' }
        setup(lines, nil, 'markdown')
        util.assert_view(util.marks(), lines)
    end)

    it('markdown still gets block rules', function()
        setup({ '<ul>', '<li>one</li>', '</ul>' }, nil, 'markdown')
        local marks = util.marks()
        hide(marks, { 0, 0 }, { 0, 4 })
        inline(marks, 1, 0, '● ')
        marks:add({ 1, 1 }, { 0, 4 }, util.conceal())
        marks:add({ 1, 1 }, { 7, 12 }, util.conceal())
        hide(marks, { 2, 2 }, { 0, 5 })
        util.assert_view(marks, { '● one' })
    end)
end)
