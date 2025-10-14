local units = require("utils.units")
local colors = require("utils.color")


local M = {}


-- Style registry: property → parse(value, ctx) → normalized
local STYLE = {}


local function add(name, fn) STYLE[name] = fn end
M.add = add


-- Built-ins
add("display", function(v) return v or "block" end)
add("gap", function(v) return tostring(v or "0") end)
add("padding", function(v) return tostring(v or "0") end)
add("margin", function(v) return tostring(v or "0") end)
add("width", function(v) return tostring(v or "auto") end)
add("height", function(v) return tostring(v or "auto") end)
add("color", function(v) return v end)
add("bg", function(v) return v end)


function M.parse_inline(s)
    local t = {}
    for decl in (s or ""):gmatch("([^;]+)") do
        local k, v = decl:match("^%s*([%w%-]+)%s*:%s*(.-)%s*$")
        if k and #k > 0 then t[k] = v end
    end
    -- Normalize via registry
    local out = {}
    for k, v in pairs(t) do
        local fn = STYLE[k]
        out[k] = fn and fn(v) or v
    end
    return out
end

-- Public helpers used by layout/renderer
function M.to_units(style)
    local s = {}
    s.widthU = units.parse_unit(style.width or "auto")
    s.heightU = units.parse_unit(style.height or "auto")
    s.padding = units.expand_box(style.padding)
    s.margin = units.expand_box(style.margin)
    s.gap = tonumber(style.gap or 0) or 0
    s.color = colors.parse_color(style.color) or colors.DEFAULT_FG
    s.bg = colors.parse_color(style.bg) or nil
    return s
end

return M
