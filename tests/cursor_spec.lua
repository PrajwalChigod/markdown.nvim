---@module 'luassert'

local util = require('tests.util')

---@param lines string[]
---@param opts? renderer.UserConfig
local function setup(lines, opts)
    local config = { file_types = { 'markdown', 'html' } }
    config = vim.tbl_deep_extend('force', config, opts or {})
    util.setup.text(lines, config, 'html')
end

---Run a normal mode command, then let the plugin react to the cursor moving
---@param keys string
---@param wait? boolean
local function press(keys, wait)
    vim.cmd.normal({ keys, bang = true })
    vim.api.nvim_exec_autocmds('CursorMoved', {})
    if wait ~= false then
        vim.wait(0)
    end
end

---@param row integer
---@param col? integer
local function assert_cursor(row, col)
    local cursor = vim.api.nvim_win_get_cursor(0)
    assert.same(row, cursor[1], 'row')
    if col then
        assert.same(col, cursor[2], 'col')
    end
end

describe('cursor', function()
    it('moves off a hidden line when first rendered', function()
        setup({ '<!DOCTYPE html>', '<html>', '<body>', 'x', '</body>' })
        assert_cursor(4)
    end)

    it('skips hidden lines going down', function()
        setup({ 'a', '<ul>', '<li>b</li>', '</ul>', 'c' })
        util.set_row(1)
        press('j')
        assert_cursor(3)
        press('j')
        assert_cursor(5)
    end)

    it('skips hidden lines going up', function()
        setup({ 'a', '<ul>', '<li>b</li>', '</ul>', 'c' })
        util.set_row(5)
        press('k')
        assert_cursor(3)
        press('k')
        assert_cursor(1)
    end)

    it('stays put when nothing visible lies ahead', function()
        setup({ '<html>', 'x', '</html>' })
        util.set_row(2)
        press('j')
        assert_cursor(2)
        press('k')
        assert_cursor(2)
    end)

    it('skips several hidden lines at once', function()
        setup({ 'a', '<ul>', '</ul>', '<ol>', '</ol>', 'b' })
        util.set_row(1)
        press('j')
        assert_cursor(6)
    end)

    it('goes to the visible line after a jump onto a hidden one', function()
        setup({ '<html>', 'x', 'y', 'z' })
        util.set_row(4)
        press('gg')
        assert_cursor(2)
    end)

    it('keeps the column the cursor wanted', function()
        setup({ 'abcdef', '<ul>', '</ul>', 'abcdef' })
        util.set_row(1)
        press('4l')
        assert_cursor(1, 4)
        press('j')
        assert_cursor(4, 4)
    end)

    it('keeps the end of line', function()
        setup({ 'abc', '<ul>', '</ul>', 'abcdef' })
        util.set_row(1)
        press('$')
        press('j')
        assert_cursor(4, 5)
    end)

    it('counts a visible line as one movement', function()
        setup({ 'a', '<ul>', 'b', '</ul>', 'c', 'd' })
        util.set_row(1)
        press('j')
        assert_cursor(3)
        press('j')
        assert_cursor(5)
        press('j')
        assert_cursor(6)
    end)

    it('does not skip when turned off', function()
        setup(
            { 'a', '<ul>', '</ul>', 'b' },
            { anti_conceal = { skip_hidden = false } }
        )
        util.set_row(1)
        press('j')
        assert_cursor(2)
    end)

    it('does not skip when the cursor line is revealed', function()
        setup({ 'a', '<ul>', '</ul>', 'b' }, {
            anti_conceal = { enabled = true },
            win_options = { concealcursor = { rendered = '' } },
        })
        util.set_row(1)
        press('j')
        assert_cursor(2)
    end)

    it('moves before the screen is drawn', function()
        setup({ 'a', '<ul>', '</ul>', 'b' })
        util.set_row(1)
        -- the update is scheduled, the cursor must not wait for it
        press('j', false)
        assert_cursor(4)
    end)

    it('counts buffer lines like the number column does', function()
        setup({ 'a', '<ul>', 'b', '</ul>', 'c', 'd', 'e' })
        util.set_row(1)
        press('4j')
        assert_cursor(5)
        press('2k')
        assert_cursor(3)
    end)

    it('finishes a count that lands on a hidden line', function()
        setup({ 'a', 'b', '<ul>', '</ul>', 'c', 'd' })
        util.set_row(1)
        press('2j')
        assert_cursor(5)
        util.set_row(6)
        press('2k')
        assert_cursor(2)
    end)

    it('steps over a table drawn as virtual lines', function()
        local body = '<tr><td>x</td></tr>'
        setup({ 'a', '<table>', body, '</table>', 'b' })
        util.set_row(1)
        press('j')
        assert_cursor(5)
        press('k')
        assert_cursor(1)
        -- the table is still drawn, the cursor never sat on its first row
        local screen = util.actual_screen()
        assert.same('a', screen[1])
        assert.same('b', screen[#screen])
        assert.is_true(#screen > 2)
    end)

    it('leaves a closed fold alone', function()
        setup({ 'a', 'b', 'c', '<ul>', '</ul>', 'd' })
        vim.wo.foldmethod = 'manual'
        vim.cmd('2,3fold')
        util.set_row(1)
        press('j')
        assert_cursor(2)
        press('j')
        assert_cursor(6)
        press('k')
        assert_cursor(2)
        vim.cmd('normal! zE')
    end)

    it('skips hidden lines in visual mode', function()
        setup({ 'a', '<ul>', '</ul>', 'b' })
        util.set_row(1)
        press('vj')
        assert.same('v', vim.fn.mode())
        assert_cursor(4)
        vim.cmd.normal({ '\27', bang = true })
    end)
end)
