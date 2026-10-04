---@type renderer.Format
return {
    name = 'markdown',
    root = 'markdown',
    languages = {
        markdown = true,
        markdown_inline = true,
        html = false,
        latex = false,
        yaml = false,
    },
    handlers = {
        html = 'renderer.handler.html',
        latex = 'renderer.handler.latex',
        markdown = 'renderer.handler.markdown',
        markdown_inline = 'renderer.handler.markdown_inline',
        yaml = 'renderer.handler.yaml',
    },
}
