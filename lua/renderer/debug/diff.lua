---@alias renderer.debug.Key string|integer

---@class renderer.debug.Diff
local M = {}

---@param t1 table<renderer.debug.Key, any>
---@param t2 table<renderer.debug.Key, any>
---@return table<renderer.debug.Key, any>?
function M.get(t1, t2)
    local keys = vim.tbl_keys(t1) ---@type renderer.debug.Key[]
    for key in pairs(t2) do
        if not vim.tbl_contains(keys, key) then
            keys[#keys + 1] = key
        end
    end
    local result = {} ---@type table<renderer.debug.Key, any>
    for _, key in ipairs(keys) do
        local difference ---@type any
        local v1, v2 = t1[key], t2[key]
        if type(v1) == 'table' and type(v2) == 'table' then
            difference = M.get(v1, v2)
        elseif v2 == nil then
            difference = vim.NIL
        elseif v1 ~= v2 then
            difference = v2
        end
        result[key] = difference
    end
    return vim.tbl_count(result) > 0 and result or nil
end

return M
