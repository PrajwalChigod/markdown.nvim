if vim.g.loaded_render_markdown then
    return
end
vim.g.loaded_render_markdown = true

if vim.fn.has('nvim-0.12') == 0 then
    vim.notify_once(
        'render-markdown.nvim requires neovim >= 0.12',
        vim.log.levels.ERROR
    )
    return
end

require('render-markdown').setup(vim.g.render_markdown_config)
require('render-markdown.core.colors').init()
require('render-markdown.core.command').init()
require('render-markdown.core.log').init()
require('render-markdown.core.manager').init()
