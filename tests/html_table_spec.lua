---@module 'luassert'

local util = require('tests.util')

---@param lines string[]
---@param opts? renderer.UserConfig
local function setup(lines, opts)
    local config = { file_types = { 'markdown', 'html' } }
    config = vim.tbl_deep_extend('force', config, opts or {})
    util.setup.text(lines, config, 'html')
end

---The cursor starts on the first line, a table never renders under it, so
---every table sits below a line of text.
---@param table_lines string[]
---@return string[]
local function page(table_lines)
    return vim.list_extend({ 'x' }, table_lines)
end

---@param marks renderer.test.Marks
---@param rows renderer.test.Range
---@param last_col integer
---@param after integer row the virtual lines are drawn above
---@param lines renderer.mark.Line[]
local function replace(marks, rows, last_col, after, lines)
    marks:add(rows, { 0, last_col }, util.conceal_lines())
    marks:add(after, 0, { virt_lines = lines, virt_lines_above = true })
end

describe('html table', function()
    it('header and body rows', function()
        setup(page({
            '<table>',
            '  <tr><th>Name</th><th>Qty</th></tr>',
            '  <tr><td>Apple</td><td>3</td></tr>',
            '</table>',
        }))
        local marks = util.marks()
        replace(marks, { 1, 4 }, 8, 5, {
            {
                {
                    '┌───────┬─────┐',
                    'RmTableHead',
                },
            },
            {
                { '│ ', 'RmTableHead' },
                { 'Name', 'RmPadding' },
                { '  │ ', 'RmTableHead' },
                { 'Qty', 'RmPadding' },
                { ' │', 'RmTableHead' },
            },
            {
                {
                    '├───────┼─────┤',
                    'RmTableHead',
                },
            },
            {
                { '│ ', 'RmTableRow' },
                { 'Apple', 'RmPadding' },
                { ' │ ', 'RmTableRow' },
                { '3', 'RmPadding' },
                { '   │', 'RmTableRow' },
            },
            {
                {
                    '└───────┴─────┘',
                    'RmTableRow',
                },
            },
        })
        util.assert_view(marks, {
            'x',
            '┌───────┬─────┐',
            '│ Name  │ Qty │',
            '├───────┼─────┤',
            '│ Apple │ 3   │',
            '└───────┴─────┘',
        })
    end)

    it('cell markup and entities', function()
        setup(page({
            '<table>',
            '<tr><td><b>Pear</b> &amp; fig</td></tr>',
            '</table>',
        }))
        local marks = util.marks()
        marks:add({ 2, 2 }, { 8, 11 }, util.conceal())
        marks:add({ 2, 2 }, { 11, 15 }, {
            hl_eol = false,
            hl_group = 'RmHtmlBold',
        })
        marks:add({ 2, 2 }, { 15, 19 }, util.conceal())
        marks:add(2, 20, {
            hl_mode = 'combine',
            virt_text = { { '&', '' } },
            virt_text_pos = 'inline',
        })
        marks:add({ 2, 2 }, { 20, 25 }, util.conceal())
        replace(marks, { 1, 3 }, 8, 4, {
            { { '┌────────────┐', 'RmTableRow' } },
            {
                { '│ ', 'RmTableRow' },
                { 'Pear', 'RmPadding:RmHtmlBold' },
                { ' ', 'RmPadding' },
                { '&', '' },
                { ' fig', 'RmPadding' },
                { ' │', 'RmTableRow' },
            },
            { { '└────────────┘', 'RmTableRow' } },
        })
        util.assert_view(marks, {
            'x',
            '┌────────────┐',
            '│ Pear & fig │',
            '└────────────┘',
        })
    end)

    it('thead, tbody, caption, align and ragged rows', function()
        setup(page({
            '<table>',
            '  <caption>Fruit</caption>',
            '  <thead>',
            '    <tr>',
            '      <th>Name</th>',
            '      <th>Qty</th>',
            '    </tr>',
            '  </thead>',
            '  <tbody>',
            '    <tr><td>Apple</td><td align="right">3</td></tr>',
            '    <tr><td>Pear</td></tr>',
            '  </tbody>',
            '</table>',
        }))
        local screen = {
            'x',
            'Fruit',
            '┌───────┬─────┐',
            '│ Name  │ Qty │',
            '├───────┼─────┤',
            '│ Apple │   3 │',
            '│ Pear  │     │',
            '└───────┴─────┘',
        }
        local marks = util.marks()
        marks:add({ 1, 13 }, { 0, 8 }, util.conceal_lines())
        marks:add(14, 0, {
            virt_lines = {
                { { 'Fruit', 'RmPadding' } },
                {
                    {
                        '┌───────┬─────┐',
                        'RmTableHead',
                    },
                },
                {
                    { '│ ', 'RmTableHead' },
                    { 'Name', 'RmPadding' },
                    { '  │ ', 'RmTableHead' },
                    { 'Qty', 'RmPadding' },
                    { ' │', 'RmTableHead' },
                },
                {
                    {
                        '├───────┼─────┤',
                        'RmTableHead',
                    },
                },
                {
                    { '│ ', 'RmTableRow' },
                    { 'Apple', 'RmPadding' },
                    { ' │   ', 'RmTableRow' },
                    { '3', 'RmPadding' },
                    { ' │', 'RmTableRow' },
                },
                {
                    { '│ ', 'RmTableRow' },
                    { 'Pear', 'RmPadding' },
                    { '  │     │', 'RmTableRow' },
                },
                {
                    {
                        '└───────┴─────┘',
                        'RmTableRow',
                    },
                },
            },
            virt_lines_above = true,
        })
        util.assert_view(marks, screen)
    end)

    it('cells that span lines and tags are one line of text', function()
        setup(page({
            '<table>',
            '<tr>',
            '  <td>',
            '    one',
            '    two  <br> three',
            '  </td>',
            '  <td><a href="u">link</a></td>',
            '</tr>',
            '</table>',
        }))
        util.assert_screen({
            'x',
            '┌───────────────┬────────┐',
            '│ one two three │ 󰌹 link │',
            '└───────────────┴────────┘',
        })
    end)

    it('implicit end tags', function()
        setup(page({
            '<table>',
            '<tr><th>A<th>B',
            '<tr><td>1<td>2',
            '</table>',
        }))
        util.assert_screen({
            'x',
            '┌───┬───┐',
            '│ A │ B │',
            '├───┼───┤',
            '│ 1 │ 2 │',
            '└───┴───┘',
        })
    end)

    it('table of only headings has no delimiter', function()
        setup(page({ '<table><tr><th>A</th><th>B</th></tr></table>' }))
        util.assert_screen({
            'x',
            '┌───┬───┐',
            '│ A │ B │',
            '└───┴───┘',
        })
    end)

    it('keeps the indentation of the table', function()
        setup(
            page({ '    <table>', '      <tr><td>a</td></tr>', '    </table>' })
        )
        util.assert_screen({
            'x',
            '    ┌───┐',
            '    │ a │',
            '    └───┘',
        })
    end)

    it('wraps cells to fit the window', function()
        setup(page({
            '<table><tr><th>Name</th><th>Info</th></tr>',
            '<tr><td>alpha</td><td>'
                .. ('word '):rep(30)
                .. '</td></tr></table>',
        }))
        local screen = util.actual_screen()
        assert.same('x', screen[1])
        assert.same(80, vim.fn.strdisplaywidth(screen[2]))
        -- one row wrapped into several lines, each as wide as the border
        assert.is_true(#screen > 6)
        for i = 2, #screen do
            assert.same(80, vim.fn.strdisplaywidth(screen[i]))
        end
    end)

    it('does not wrap when turned off', function()
        local long = ('word '):rep(30)
        setup(
            page({ '<table><tr><td>' .. long .. '</td></tr></table>' }),
            { pipe_table = { wrap = false } }
        )
        local screen = util.actual_screen()
        -- one line per row, cut off by the edge of the window
        assert.same(4, #screen)
        assert.same('│ word', screen[3]:sub(1, #'│ word'))
        assert.is_false(vim.endswith(screen[3], '│'))
    end)

    it('uses the pipe_table border and padding', function()
        setup(
            page({ '<table><tr><td>a</td></tr></table>' }),
            { pipe_table = { padding = 2, border_enabled = false } }
        )
        util.assert_screen({ 'x', '│  a  │' })
    end)

    describe('left as source', function()
        ---@param lines string[]
        ---@param opts? renderer.UserConfig
        local function raw(lines, opts)
            setup(page(lines), opts)
            util.assert_view(util.marks(), page(lines))
        end

        it('colspan', function()
            raw({ '<table><tr><td colspan="2">a</td></tr></table>' })
        end)

        it('rowspan', function()
            raw({ '<table><tr><td rowspan="2">a</td></tr></table>' })
        end)

        it('table sharing its line with text', function()
            raw({ 'a <table><tr><td>a</td></tr></table>' })
        end)

        it('table without an end tag', function()
            raw({ '<table>', '<tr><td>a</td></tr>' })
        end)

        it('table taller than the view', function()
            local rows = {} ---@type string[]
            for i = 1, 100 do
                rows[i] = ('<tr><td>%d</td></tr>'):format(i)
            end
            local lines = vim.list_extend({ '<table>' }, rows)
            lines[#lines + 1] = '</table>'
            setup(page(lines))
            local screen = util.actual_screen()
            assert.same('x', screen[1])
            assert.same('<table>', screen[2])
        end)

        it('conceallevel below 2', function()
            raw(
                { '<table><tr><td>a</td></tr></table>' },
                { win_options = { conceallevel = { rendered = 1 } } }
            )
        end)

        it('switch off', function()
            raw(
                { '<table><tr><td>a</td></tr></table>' },
                { html = { table = false } }
            )
        end)

        it('pipe_table disabled', function()
            raw(
                { '<table><tr><td>a</td></tr></table>' },
                { pipe_table = { enabled = false } }
            )
        end)

        it('html disabled', function()
            raw(
                { '<table><tr><td>a</td></tr></table>' },
                { html = { enabled = false } }
            )
        end)
    end)

    it('leaves a table with a nested table, the inner one renders', function()
        setup(page({
            '<table><tr><td>',
            '<table><tr><td>x</td></tr></table>',
            '</td></tr></table>',
        }))
        util.assert_screen({
            'x',
            '<table><tr><td>',
            '┌───┐',
            '│ x │',
            '└───┘',
            '</td></tr></table>',
        })
    end)

    it('shows the source under the cursor', function()
        setup(page({ '<table>', '  <tr><td>a</td></tr>', '</table>' }))
        util.set_row(2)
        util.assert_screen({
            'x',
            '<table>',
            '  <tr><td>a</td></tr>',
            '</table>',
        })
    end)

    it('also renders inside markdown', function()
        local lines = { 'x', '', '<table>', '<tr><td>a</td></tr>', '</table>' }
        util.setup.text(lines, nil, 'markdown')
        util.assert_screen({
            'x',
            '',
            '┌───┐',
            '│ a │',
            '└───┘',
        })
    end)
end)
