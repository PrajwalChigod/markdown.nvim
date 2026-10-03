if vim.g.loaded_renderer then
    return
end
vim.g.loaded_renderer = true

if vim.fn.has('nvim-0.12') == 0 then
    vim.notify_once(
        'renderer.nvim requires neovim >= 0.12',
        vim.log.levels.ERROR
    )
    return
end

require('renderer').setup(vim.g.renderer_config)
require('renderer.core.colors').init()
require('renderer.core.command').init()
require('renderer.core.log').init()
require('renderer.core.manager').init()
