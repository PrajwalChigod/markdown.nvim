---@type renderer.Format
return {
    name = 'html',
    root = 'html',
    languages = { html = true },
    handlers = { html = 'renderer.handler.html' },
}
