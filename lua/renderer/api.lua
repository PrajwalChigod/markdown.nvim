---@class renderer.render.Context
---@field buf integer
---@field win? integer|integer[]
---@field event? string
---@field config? renderer.partial.UserConfig

---@class renderer.Api
local M = {}

---@param ctx renderer.render.Context
function M.render(ctx)
    local env = require('renderer.lib.env')
    local list = require('renderer.lib.list')
    local state = require('renderer.state')
    local ui = require('renderer.core.ui')

    local buf = ctx.buf
    local wins = list.ensure(ctx.win or env.buf.wins(buf))
    local event = ctx.event or 'Api'

    state.get(buf, ctx.config)
    state.attach()

    for _, win in ipairs(wins) do
        ui.update(buf, win, event, true)
    end
end

---@return boolean
function M.get()
    return require('renderer.state').enabled
end

---@param enable? boolean
function M.set(enable)
    require('renderer.core.manager').set(enable)
end

---@param enable? boolean
function M.set_buf(enable)
    require('renderer.core.manager').set_buf(nil, enable)
end

function M.enable()
    M.set(true)
end

function M.buf_enable()
    M.set_buf(true)
end

function M.disable()
    M.set(false)
end

function M.buf_disable()
    M.set_buf(false)
end

function M.toggle()
    M.set()
end

function M.buf_toggle()
    M.set_buf()
end

function M.preview()
    require('renderer.core.preview').open()
end

function M.log()
    require('renderer.core.log').open()
end

function M.expand()
    require('renderer.state').modify_anti_conceal(1)
    M.enable()
end

function M.contract()
    require('renderer.state').modify_anti_conceal(-1)
    M.enable()
end

function M.debug()
    require('renderer.debug.marks').show()
end

function M.config()
    local difference = require('renderer.state').difference()
    if not difference then
        -- selene: allow(deprecated)
        vim.print('default configuration')
    else
        -- selene: allow(deprecated)
        vim.print(difference)
    end
end

return M
