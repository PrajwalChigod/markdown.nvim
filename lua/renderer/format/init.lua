local env = require('renderer.lib.env')

---@class renderer.Format
---@field name string
---@field root string root treesitter language
---@field languages table<string, boolean> treesitter language -> required
---@field handlers table<string, string> treesitter language -> handler module
---@field defaults? renderer.partial.UserConfig
---@field scroll? boolean keep rendering when scrolled sideways

---@class renderer.format.Registry
local M = {}

---@private
---@type string[]
M.names = { 'markdown', 'html' }

---@private
---@type table<string, renderer.Format>
M.loaded = {}

---@return renderer.Format[]
function M.all()
    local result = {} ---@type renderer.Format[]
    for _, name in ipairs(M.names) do
        if not M.loaded[name] then
            M.loaded[name] = require('renderer.format.' .. name)
        end
        result[#result + 1] = M.loaded[name]
    end
    return result
end

---Find the format from the root treesitter language rather than the filetype,
---users map filetypes such as rmd onto the markdown parser.
---@param buf integer
---@return renderer.Format?
function M.get(buf)
    local filetype = env.buf.get(buf, 'filetype')
    return M.root(vim.treesitter.language.get_lang(filetype))
end

---@param language? string
---@return renderer.Format?
function M.root(language)
    for _, format in ipairs(M.all()) do
        if format.root == language then
            return format
        end
    end
    return nil
end

---@param language string
---@return string?
function M.handler(language)
    local result ---@type string?
    for _, format in ipairs(M.all()) do
        local module = format.handlers[language]
        if module then
            assert(
                not result or result == module,
                ('conflicting handlers for %s: %s, %s'):format(
                    language,
                    result,
                    module
                )
            )
            result = module
        end
    end
    return result
end

return M
