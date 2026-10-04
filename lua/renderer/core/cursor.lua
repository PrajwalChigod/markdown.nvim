local env = require('renderer.lib.env')

---Neovim hides lines marked with `conceal_lines` but still lets the cursor
---move onto them, so `j` and `k` appear to do nothing until the hidden lines
---have been walked through. This moves the cursor past them
---@class renderer.Cursor
local M = {}

---@class (exact) renderer.cursor.Last
---@field row integer 0-indexed row the cursor was seen on
---@field step -1|1 direction the cursor was travelling

---@private
---Modes where the cursor can be moved without disturbing a pending command
---@type string[]
M.modes = { 'n', 'v', 'V', '\22' }

---@private
---@type table<integer, renderer.cursor.Last>
M.last = {}

---Move the cursor off a line that is hidden completely, in the direction it was
---travelling. Does nothing while the cursor line is revealed, which is the case
---when 'concealcursor' does not include the mode
---@param buf integer
---@param win integer
---@param mode string
function M.skip(buf, win, mode)
    local row = env.row.get(buf, win)
    if not row or win ~= env.win.current() then
        return
    end
    -- the cursor does not move when marks are drawn under it, i.e. on first
    -- render, so the direction it last travelled in is kept
    local last = M.last[win]
    local step = last and last.step or 1
    if last and row ~= last.row then
        step = row < last.row and -1 or 1
    end
    M.last[win] = { row = row, step = step }
    if not vim.tbl_contains(M.modes, mode) or not M.hidden(win, row) then
        return
    end
    local target = M.find(buf, win, row, step)
    if target then
        M.move(buf, win, target)
    else
        -- nothing visible lies ahead, so go back to the last line that is
        target = M.find(buf, win, row, -step)
        if target and M.fits(win, target, step) then
            M.move(buf, win, target)
        else
            target = nil
        end
    end
    if target then
        M.last[win].row = target
    end
end

---Forget the window, called when it is closed or no longer rendered
---@param win integer
function M.forget(win)
    M.last[win] = nil
end

---@private
---Neovim computes the height of a hidden line as 0, and accounts for the cursor
---line and 'concealcursor' when doing so
---@param win integer
---@param row integer
---@return boolean
function M.hidden(win, row)
    local range = { start_row = row, end_row = row }
    return vim.api.nvim_win_text_height(win, range).all == 0
end

---@private
---@param buf integer
---@param win integer
---@param row integer
---@param step integer
---@return integer?
function M.find(buf, win, row, step)
    local count = vim.api.nvim_buf_line_count(buf)
    row = row + step
    while row >= 0 and row < count do
        if not M.hidden(win, row) then
            -- a closed fold is entered at its first line, as `j` and `k` do
            local fold = vim.api.nvim_win_call(win, function()
                return vim.fn.foldclosed(row + 1)
            end)
            return fold == -1 and row or fold - 1
        end
        row = row + step
    end
    return nil
end

---@private
---Whether the cursor can go back to a row behind it without the window
---scrolling. Neovim keeps the cursor 'scrolloff' lines below the top of the
---window, and when scrolling carries the cursor onto hidden lines at the end of
---the buffer the last visible row is closer to the top than that. Putting the
---cursor back on it would make Neovim undo the scroll, so the window could never
---get past that point. The cursor is then left on the hidden line, where Neovim
---put it
---@param win integer
---@param row integer
---@param step -1|1 direction the cursor was travelling
---@return boolean
function M.fits(win, row, step)
    -- going back down only happens at the start of the buffer
    if step == -1 then
        return true
    end
    local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    local top = view.topline - 1
    if row < top then
        return false
    end
    local function height(first, last)
        local range = { start_row = first, end_row = last }
        return vim.api.nvim_win_text_height(win, range)
    end
    -- nothing can scroll into view above, Neovim then lets the cursor be
    if top == 0 or height(0, top - 1).all == 0 then
        return true
    end
    local above = view.topfill
    if row > top then
        -- virtual lines above the top row are only shown in part
        above = above + height(top, row - 1).all - height(top, top).fill
    end
    local offset = vim.api.nvim_get_option_value('scrolloff', { win = win })
    local limit = math.floor((vim.api.nvim_win_get_height(win) - 1) / 2)
    return above >= math.min(offset, limit)
end

---@private
---Keeps the column the cursor wanted, so `j` and `k` stay in the same column
---@param buf integer
---@param win integer
---@param row integer
function M.move(buf, win, row)
    local view = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
    local last = math.max(#line - 1, 0)
    local col = last
    if view.curswant < vim.v.maxcol then
        local byte = vim.fn.virtcol2col(win, row + 1, view.curswant + 1)
        col = math.min(math.max(byte - 1, 0), last)
    end
    vim.api.nvim_win_call(win, function()
        vim.fn.winrestview({
            lnum = row + 1,
            col = col,
            curswant = view.curswant,
        })
    end)
end

return M
