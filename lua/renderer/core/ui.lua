local Context = require('renderer.request.context')
local env = require('renderer.lib.env')
local iter = require('renderer.lib.iter')
local log = require('renderer.core.log')
local state = require('renderer.state')
local str = require('renderer.lib.str')

---@class renderer.Ui
local M = {}

M.ns = vim.api.nvim_create_namespace('renderer.nvim')

---@private
---@type table<integer, renderer.Decorator>
M.cache = {}

---called from state on setup
function M.setup()
    -- clear marks and reset cache
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    end
    M.cache = {}
end

---@param buf integer
---@return renderer.Decorator
function M.get(buf)
    local result = M.cache[buf]
    if not result then
        result = require('renderer.lib.decorator').new(buf)
        M.cache[buf] = result
    end
    return result
end

---@param buf integer
---@param win integer
---@param event string
---@param force boolean
function M.update(buf, win, event, force)
    log.buf('info', 'Update', buf, event, ('force %s'):format(force))
    M.updater.new(buf, win, force):start()
end

---@class renderer.ui.Updater
---@field private buf integer
---@field private win integer
---@field private force boolean
---@field private decorator renderer.Decorator
---@field private config renderer.buf.Config
---@field private mode string
local Updater = {}
Updater.__index = Updater

---@param buf integer
---@param win integer
---@param force boolean
---@return renderer.ui.Updater
function Updater.new(buf, win, force)
    local self = setmetatable({}, Updater)
    self.buf = buf
    self.win = win
    self.force = force
    self.decorator = M.get(buf)
    self.config = state.get(buf)
    return self
end

function Updater:start()
    if not env.valid(self.buf, self.win) then
        return
    end
    self.decorator:schedule(
        self:changed() and not env.buf.empty(self.buf),
        self.config.debounce,
        log.runtime('update', function()
            self:run()
        end)
    )
end

---@private
---@return boolean
function Updater:changed()
    -- force or buffer has changed or we have not handled the visible range yet
    return self.force
        or self.decorator:changed()
        or not Context.contains(self.buf, self.win)
end

---@private
function Updater:run()
    if not env.valid(self.buf, self.win) then
        return
    end
    self.mode = env.mode.get() -- mode is only available after this point
    local render = self.config.enabled
        and self.config.resolved:render(self.mode)
        and env.win.view(self.win).leftcol == 0
        and (self.config.render.diff or not env.win.get(self.win, 'diff'))
    log.buf('info', 'Render', self.buf, render)
    local next_state = render and 'rendered' or 'default'
    for _, win in ipairs(env.buf.wins(self.buf)) do
        for name, value in pairs(self.config.win_options) do
            env.win.set(win, name, value[next_state])
        end
    end
    if not render then
        self:clear()
    else
        self:render()
    end
end

---@private
function Updater:clear()
    self.decorator:clear(M.ns)
    vim.api.nvim_buf_clear_namespace(self.buf, M.ns, 0, -1)
    state.on.clear({ buf = self.buf, win = self.win })
end

---@private
function Updater:render()
    if self:changed() then
        self:parse(function(extmarks)
            if not extmarks then
                return
            end
            local initial = self.decorator:initial()
            self:clear()
            self.decorator:set(extmarks)
            if initial then
                M.fix_lsp_window(self.buf, self.win, extmarks)
                state.on.initial({ buf = self.buf, win = self.win })
            end
            self:display()
        end)
    else
        self:display()
    end
end

---@private
---@param callback fun(extmarks: renderer.Extmark[]|nil)
function Updater:parse(callback)
    local parser = vim.treesitter.get_parser(self.buf)
    if parser then
        -- reset buffer context
        local context = Context.new(self.buf, self.win, self.config)
        if context then
            -- make sure injections are processed
            context.view:parse(parser, function()
                local Extmark = require('renderer.lib.extmark')
                local handlers = require('renderer.core.handlers')
                local marks = handlers.run(context, parser)
                callback(iter.list.map(marks, Extmark.new))
            end)
        else
            log.buf('debug', 'Skip', self.buf, 'in progress')
            callback(nil)
        end
    else
        log.buf('error', 'Fail', self.buf, 'no treesitter parser found')
        callback(nil)
    end
end

---@private
function Updater:display()
    local range = self:hidden()
    self.decorator:display(M.ns, function(extmark)
        return self:hide(extmark, range)
    end)
    state.on.render({ buf = self.buf, win = self.win })
end

---@private
---@return renderer.Range?
function Updater:hidden()
    -- anti-conceal is not enabled -> hide nothing
    -- in disabled mode -> hide nothing
    local config = self.config.anti_conceal
    if not config.enabled or env.mode.is(self.mode, config.disabled_modes) then
        return nil
    end
    -- row is not known -> buffer is not active -> hide nothing
    local row = env.row.get(self.buf, self.win)
    if not row then
        return nil
    end
    if env.mode.is(self.mode, { 'v', 'V', '\22' }) then
        local start = vim.fn.getpos('v')[2] - 1
        ---@type renderer.Range
        return { math.min(row, start), math.max(row, start) }
    else
        ---@type renderer.Range
        return { row - config.above, row + config.below }
    end
end

---@private
---@param extmark renderer.Extmark
---@param range? renderer.Range
---@return boolean
function Updater:hide(extmark, range)
    local mark = extmark:get()

    -- virtual row -> no editable screen cells -> must hide
    if mark.replace then
        local row = env.row.get(self.buf, self.win)
        if row and row == mark.start_row then
            return true
        end
    end

    -- not in top level or mark level modes -> hide
    local show = env.mode.join(self.config.render_modes, mark.modes)
    if not env.mode.is(self.mode, show) then
        return true
    end

    -- does not overlap with hidden range -> show
    if not extmark:overlaps(range) then
        return false
    end

    local conceal = mark.conceal
    if type(conceal) == 'boolean' then
        -- mark has conceal value -> respect
        return conceal
    else
        -- mark has conceal element -> show if anti-conceal is ignored
        local ignore = self.config.anti_conceal.ignore[conceal]
        return not (ignore and env.mode.is(self.mode, ignore))
    end
end

---@private
---@param buf integer
---@param win integer
---@param extmarks renderer.Extmark[]
---@see vim.lsp.util.open_floating_preview
function M.fix_lsp_window(buf, win, extmarks)
    -- this is a fragile way of identifying whether this is a floating LSP
    -- window, comes from the implementation and not from any documentation
    local has_lsp = pcall(vim.api.nvim_win_get_var, win, 'lsp_floating_bufnr')
    if not has_lsp then
        return
    end

    -- account for conceal lines marks allowing us to reduce window height
    local height = vim.api.nvim_win_text_height(win, {}).all ---@type integer
    for _, extmark in ipairs(extmarks) do
        if extmark:get().opts.conceal_lines then
            height = height - 1
        end
    end
    if height < vim.api.nvim_win_get_height(win) then
        vim.api.nvim_win_set_height(win, height)
    end

    -- disable line wrapping if it is not needed to contain the text
    local width = 0 ---@type integer
    for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        width = math.max(width, str.width(line))
    end
    if width <= vim.api.nvim_win_get_width(win) then
        env.win.set(win, 'wrap', false)
    end
end

---@private
M.updater = Updater

return M
