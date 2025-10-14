local M = {}


function M.shallow_copy(t)
    local r = {}; for k, v in pairs(t or {}) do r[k] = v end; return r
end

function M.clamp(v, a, b)
    if a and v < a then return a end; if b and v > b then return b end; return v
end

function M.parse_unit(s)
    if s == nil or s == "" or s == "auto" then return { kind = "auto" } end
    local pct = s:match("^(%-?[%d%.]+)%%$"); if pct then return { kind = "pct", v = tonumber(pct) / 100 } end
    local num = s:match("^(%-?[%d%.]+)$"); if num then return { kind = "abs", v = math.floor(tonumber(num)) } end
    return { kind = "auto" }
end

function M.unit_to_px(u, base, fallback)
    if not u or u.kind == "auto" then return fallback end
    if u.kind == "abs" then return u.v end
    if u.kind == "pct" then return math.max(0, math.floor((base or 0) * u.v + 0.5)) end
    return fallback
end

function M.expand_box(v)
    if not v or v == "" then return { 0, 0, 0, 0 } end
    local a, b, c, d = v:match("^%s*(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*$")
    if a then return { tonumber(a), tonumber(b), tonumber(c), tonumber(d) } end
    a, b = v:match("^%s*(%d+)%s+(%d+)%s*$")
    if a then
        a, b = tonumber(a), tonumber(b); return { a, b, a, b }
    end
    a = v:match("^%s*(%d+)%s*$"); if a then
        a = tonumber(a); return { a, a, a, a }
    end
    return { 0, 0, 0, 0 }
end

return M
