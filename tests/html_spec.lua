---@module 'luassert'

local util = require('tests.util')

---@param kind string
---@return vim.api.keyset.set_extmark
local function scope(kind)
    ---@type vim.api.keyset.set_extmark
    return { hl_eol = false, hl_group = 'RmHtml' .. kind }
end

describe('html', function()
    it('inline bold', function()
        util.setup.text({ '<b>bold</b>' })
        local marks = util.marks()
        marks:add({ 0, 0 }, { 0, 3 }, util.conceal())
        marks:add({ 0, 0 }, { 3, 7 }, scope('Bold'))
        marks:add({ 0, 0 }, { 7, 11 }, util.conceal())
        util.assert_view(marks, { 'bold' })
    end)

    it('inline italic with surrounding text', function()
        util.setup.text({ 'a <em>b</em> c' })
        local marks = util.marks()
        marks:add({ 0, 0 }, { 2, 6 }, util.conceal())
        marks:add({ 0, 0 }, { 6, 7 }, scope('Italic'))
        marks:add({ 0, 0 }, { 7, 12 }, util.conceal())
        util.assert_view(marks, { 'a b c' })
    end)

    it('inline unmatched start tag', function()
        util.setup.text({ '<b>bold' })
        util.assert_view(util.marks(), { '<b>bold' })
    end)

    it('inline unknown tag', function()
        util.setup.text({ '<foo>bar</foo>' })
        util.assert_view(util.marks(), { '<foo>bar</foo>' })
    end)

    it('disabled', function()
        util.setup.text({ '<b>bold</b>' }, { html = { enabled = false } })
        util.assert_view(util.marks(), { '<b>bold</b>' })
    end)

    it('img alt text', function()
        util.setup.text({ '<img src="a.png" alt="logo">' })
        local marks = util.marks()
        marks:add(0, 0, {
            virt_text = { { '󰥶 logo', 'RmLink' } },
            virt_text_pos = 'inline',
        })
        marks:add({ 0, 0 }, { 0, 28 }, util.conceal())
        util.assert_view(marks, { '󰥶 logo' })
    end)

    it('br', function()
        util.setup.text({ 'a<br>b' })
        local marks = util.marks()
        marks:add({ 0, 0 }, { 1, 5 }, util.conceal())
        util.assert_view(marks, { 'ab' })
    end)

    it('block tag', function()
        util.setup.text({ '<div>', '', '<b>bold</b>', '', '</div>' })
        local marks = util.marks()
        marks:add({ 0, 0 }, { 0, 5 }, util.conceal())
        marks:add({ 2, 2 }, { 0, 3 }, util.conceal())
        marks:add({ 2, 2 }, { 3, 7 }, scope('Bold'))
        marks:add({ 2, 2 }, { 7, 11 }, util.conceal())
        marks:add({ 4, 4 }, { 0, 6 }, util.conceal())
        util.assert_view(marks, { '', '', 'bold', '', '' })
    end)

    it('align center', function()
        util.setup.text({ '<h1 align="center" id="riftnvim">rift.nvim</h1>' })
        local marks = util.marks()
        marks:add(0, 0, {
            virt_text = { { (' '):rep(35), 'Normal' } },
            virt_text_pos = 'inline',
        })
        marks:add({ 0, 0 }, { 0, 33 }, util.conceal())
        marks:add({ 0, 0 }, { 33, 42 }, { hl_eol = false, hl_group = 'RmH1' })
        marks:add({ 0, 0 }, { 42, 47 }, util.conceal())
        util.assert_view(marks, { (' '):rep(35) .. 'rift.nvim' })
    end)

    it('align center multiline skips tag only lines', function()
        util.setup.text({ '<p align="center">', '  <b>hi</b>', '</p>' })
        local marks = util.marks()
        marks:add({ 0, 0 }, { 0, 18 }, util.conceal())
        marks:add(1, 2, {
            virt_text = { { (' '):rep(39), 'Normal' } },
            virt_text_pos = 'inline',
        })
        marks:add({ 1, 1 }, { 2, 5 }, util.conceal())
        marks:add({ 1, 1 }, { 5, 7 }, scope('Bold'))
        marks:add({ 1, 1 }, { 7, 11 }, util.conceal())
        marks:add({ 2, 2 }, { 0, 4 }, util.conceal())
        util.assert_view(marks, { '', '  ' .. (' '):rep(39) .. 'hi', '' })
    end)
end)
