---@class renderer.lib.Entities
local M = {}

---@private
---@type table<string, integer>
M.named = {
    amp = 0x26,
    lt = 0x3C,
    gt = 0x3E,
    quot = 0x22,
    apos = 0x27,
    nbsp = 0x20,
    copy = 0xA9,
    reg = 0xAE,
    trade = 0x2122,
    hellip = 0x2026,
    mdash = 0x2014,
    ndash = 0x2013,
    lsquo = 0x2018,
    rsquo = 0x2019,
    ldquo = 0x201C,
    rdquo = 0x201D,
    laquo = 0xAB,
    raquo = 0xBB,
    bull = 0x2022,
    middot = 0xB7,
    deg = 0xB0,
    plusmn = 0xB1,
    times = 0xD7,
    divide = 0xF7,
    euro = 0x20AC,
    pound = 0xA3,
    yen = 0xA5,
    cent = 0xA2,
    sect = 0xA7,
    para = 0xB6,
    larr = 0x2190,
    rarr = 0x2192,
    uarr = 0x2191,
    darr = 0x2193,
    hearts = 0x2665,
    check = 0x2713,
}

---Character an entity stands for, nil when it is unknown or incomplete
---@param text string like `&amp;`, `&#169;` or `&#xA9;`
---@return string?
function M.decode(text)
    local body = text:match('^&(.-);$')
    if not body then
        return nil
    end
    local code = M.named[body] ---@type integer?
    local hex = body:match('^#[xX](%x+)$')
    local dec = body:match('^#(%d+)$')
    if hex then
        code = tonumber(hex, 16)
    elseif dec then
        code = tonumber(dec)
    end
    local surrogate = code and code >= 0xD800 and code <= 0xDFFF
    if not code or code < 1 or code > 0x10FFFF or surrogate then
        return nil
    end
    return vim.fn.nr2char(code)
end

return M
