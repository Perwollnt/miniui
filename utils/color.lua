local M = {}


M.COLOR = {
    white = colors.white,
    orange = colors.orange,
    magenta = colors.magenta,
    lightBlue = colors.lightBlue,
    yellow = colors.yellow,
    lime = colors.lime,
    pink = colors.pink,
    gray = colors.gray,
    lightGray = colors.lightGray,
    cyan = colors.cyan,
    purple = colors.purple,
    blue = colors.blue,
    brown = colors.brown,
    green = colors.green,
    red = colors.red,
    black = colors.black,
}


local ORDER = { "white", "orange", "magenta", "lightBlue", "yellow", "lime", "pink", "gray", "lightGray", "cyan",
    "purple", "blue", "brown", "green", "red", "black" }


local NAME_ALIAS = {
    ["light-blue"] = "lightBlue",
    ["lightblue"] = "lightBlue",
    ["lightgray"] = "lightGray",
    ["light-grey"] = "lightGray",
    ["grey"] = "gray",
}


M.DEFAULT_FG = M.COLOR.white
M.DEFAULT_BG = M.COLOR.black


local function _strip_quotes(s)
    if not s then return nil end
    s = s:match("^%s*(.-)%s*$")
    local q = s:sub(1, 1)
    if (q == '"' or q == "'") and s:sub(-1) == q then return s:sub(2, -2) end
    return s
end


local function hex_to_rgb(s)
    s = s:lower()
    local a3 = s:match("^#([0-9a-f][0-9a-f][0-9a-f])$")
    if a3 then
        local r = tonumber(a3:sub(1, 1), 16) * 17
        local g = tonumber(a3:sub(2, 2), 16) * 17
        local b = tonumber(a3:sub(3, 3), 16) * 17
        return r / 255, g / 255, b / 255
    end
    local a6 = s:match("^#([0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f])$")
    if a6 then
        local r = tonumber(a6:sub(1, 2), 16)
        local g = tonumber(a6:sub(3, 4), 16)
        local b = tonumber(a6:sub(5, 6), 16)
        return r / 255, g / 255, b / 255
    end
end


local function rgb_fn_to_rgb(s)
    local r, g, b = s:match("^rgb%s*%(%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*%)%s*$")
    if r then
        r, g, b = tonumber(r), tonumber(g), tonumber(b)
        local function cl(x) return math.max(0, math.min(255, x)) / 255 end
        return cl(r), cl(g), cl(b)
    end
end


function M.parse_color(name)
    if not name then return nil end
    local v = _strip_quotes(name)
    if not v or v == "" then return nil end
    local key = v:gsub("_", "-")
    local lower = key:lower()
    local alias = NAME_ALIAS[lower]
    if alias then return M.COLOR[alias] end
    for k, _ in pairs(M.COLOR) do if k:lower() == lower then return M.COLOR[k] end end
    local num = tonumber(v)
    if num and num >= 0 and num <= 15 then return M.COLOR[ORDER[num + 1]] end
    local PALETTE = {
        white = { 1, 1, 1 },
        orange = { 1, 0.5, 0 },
        magenta = { 1, 0, 1 },
        lightBlue = { 0.5, 0.75, 1 },
        yellow = { 1, 1, 0 },
        lime = { 0.5, 1, 0.5 },
        pink = { 1, 0.5, 0.5 },
        gray = { 0.3, 0.3, 0.3 },
        lightGray = { 0.6, 0.6, 0.6 },
        cyan = { 0, 1, 1 },
        purple = { 0.5, 0, 0.5 },
        blue = { 0, 0, 1 },
        brown = { 0.6, 0.4, 0.2 },
        green = { 0, 1, 0 },
        red = { 1, 0, 0 },
        black = { 0, 0, 0 },
    }
    local r, g, b = hex_to_rgb(v); if not r then r, g, b = rgb_fn_to_rgb(v) end
    if r then
        local best, bestName = 1e9, "white"
        for name, rgb in pairs(PALETTE) do
            local dr, dg, db = r - rgb[1], g - rgb[2], b - rgb[3]
            local d = dr * dr + dg * dg + db * db
            if d < best then best, bestName = d, name end
        end
        return M.COLOR[bestName]
    end
    return nil
end

return M
