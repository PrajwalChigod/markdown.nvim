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
end)
