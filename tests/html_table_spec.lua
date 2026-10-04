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

---Marks of a table replaced as a whole with virtual lines
---@param marks renderer.test.Marks
---@param rows renderer.test.Range
---@param last_col integer
---@param after integer row the virtual lines are drawn above
---@param lines renderer.mark.Line[]
local function replace(marks, rows, last_col, after, lines)
    marks:add(rows, { 0, last_col }, util.conceal_lines())
    marks:add(after, 0, { virt_lines = lines, virt_lines_above = true })
end

---Marks of a table drawn over the first line of each of its rows
---@param marks renderer.test.Marks
---@param rows renderer.test.Range rows of the table
---@param kept integer[] row each table row is drawn over
---@param after integer row the last virtual lines are drawn above
---@param groups renderer.mark.Line[][] lines above the first row, then of each row
local function draw(marks, rows, kept, after, groups)
    ---@param row integer
    ---@return integer
    local function len(row)
        return #vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1]
    end
    ---@param first integer
    ---@param last integer
    local function hide(first, last)
        if first <= last then
            marks:add({ first, last }, { 0, len(last) }, util.conceal_lines())
        end
    end
    local start = rows[1]
    for i, row in ipairs(kept) do
        hide(start, row - 1)
        start = row + 1
        local before = i == 1 and groups[1] or vim.list_slice(groups[i], 2)
        if #before > 0 then
            marks:add(row, 0, { virt_lines = before, virt_lines_above = true })
        end
        marks:add({ row, row }, { 0, len(row) }, util.conceal())
        marks:add(row, 0, {
            virt_text = groups[i + 1][1],
            virt_text_pos = 'overlay',
        })
    end
    local last = assert(rows[2], 'missing second row')
    hide(start, last - 1)
    hide(last, last)
    local below = vim.list_slice(groups[#groups], 2)
    if #below > 0 then
        marks:add(after, 0, { virt_lines = below, virt_lines_above = true })
    end
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
        draw(marks, { 1, 4 }, { 2, 3 }, 5, {
            {
                {
                    {
                        '┌───────┬─────┐',
                        'RmTableHead',
                    },
                },
            },
            {
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
            },
            {
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
        draw(marks, { 1, 3 }, { 2 }, 4, {
            {
                {
                    {
                        '┌────────────┐',
                        'RmTableRow',
                    },
                },
            },
            {
                {
                    { '│ ', 'RmTableRow' },
                    { 'Pear', 'RmPadding:RmHtmlBold' },
                    { ' ', 'RmPadding' },
                    { '&', '' },
                    { ' fig', 'RmPadding' },
                    { ' │', 'RmTableRow' },
                },
                {
                    {
                        '└────────────┘',
                        'RmTableRow',
                    },
                },
            },
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
        draw(marks, { 1, 13 }, { 4, 10, 11 }, 14, {
            {
                { { 'Fruit', 'RmPadding' } },
                {
                    {
                        '┌───────┬─────┐',
                        'RmTableHead',
                    },
                },
            },
            {
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
            },
            {
                {
                    { '│ ', 'RmTableRow' },
                    { 'Apple', 'RmPadding' },
                    { ' │   ', 'RmTableRow' },
                    { '3', 'RmPadding' },
                    { ' │', 'RmTableRow' },
                },
            },
            {
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

    it('rows sharing a line are drawn as virtual lines', function()
        setup(page({
            '<table>',
            '<tr><td>a</td></tr><tr><td>b</td></tr>',
            '</table>',
        }))
        local marks = util.marks()
        replace(marks, { 1, 3 }, 8, 4, {
            { { '┌───┐', 'RmTableRow' } },
            {
                { '│ ', 'RmTableRow' },
                { 'a', 'RmPadding' },
                { ' │', 'RmTableRow' },
            },
            {
                { '│ ', 'RmTableRow' },
                { 'b', 'RmPadding' },
                { ' │', 'RmTableRow' },
            },
            { { '└───┘', 'RmTableRow' } },
        })
        util.assert_view(marks, {
            'x',
            '┌───┐',
            '│ a │',
            '│ b │',
            '└───┘',
        })
    end)

    it('a row wider than the window is drawn as virtual lines', function()
        -- the line of the row wraps, so it would take two lines on screen
        vim.o.wrap = true
        local cell = ('<i>a</i>'):rep(12)
        setup(
            page({ '<table>', '<tr><td>' .. cell .. '</td></tr>', '</table>' })
        )
        util.assert_screen({
            'x',
            '┌──────────────┐',
            '│ aaaaaaaaaaaa │',
            '└──────────────┘',
        })
        -- nothing of the table is left for the cursor to rest on
        vim.cmd.normal({ 'j', bang = true })
        vim.api.nvim_exec_autocmds('CursorMoved', {})
        vim.wait(0)
        local row = vim.api.nvim_win_get_cursor(0)[1]
        vim.o.wrap = false
        assert.same(1, row)
    end)

    it('the cursor moves through the rows', function()
        setup(page({
            '<table>',
            '  <tr><th>Name</th></tr>',
            '  <tr>',
            '    <td>Apple</td>',
            '  </tr>',
            '  <tr><td>Pear</td></tr>',
            '</table>',
            'y',
        }))
        local screen = {
            'x',
            '┌───────┐',
            '│ Name  │',
            '├───────┤',
            '│ Apple │',
            '│ Pear  │',
            '└───────┘',
            'y',
        }
        ---@param keys string
        ---@return integer
        local function press(keys)
            vim.cmd.normal({ keys, bang = true })
            vim.api.nvim_exec_autocmds('CursorMoved', {})
            vim.wait(0)
            return vim.api.nvim_win_get_cursor(0)[1]
        end
        local rows = {} ---@type integer[]
        for _ = 1, 4 do
            rows[#rows + 1] = press('j')
        end
        assert.same({ 3, 4, 7, 9 }, rows)
        util.assert_screen(screen)
        rows = {}
        for _ = 1, 4 do
            rows[#rows + 1] = press('k')
        end
        assert.same({ 7, 4, 3, 1 }, rows)
        util.assert_screen(screen)
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
        -- a table replaced as a whole, which the cursor only reaches when it
        -- does not skip hidden lines
        local opts = { anti_conceal = { skip_hidden = false } }
        setup(page({ '<table><tr><td>a</td></tr></table>' }), opts)
        util.set_row(2)
        util.assert_screen({ 'x', '<table><tr><td>a</td></tr></table>' })
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
