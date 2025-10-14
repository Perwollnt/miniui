local M = {}

local function within(x, y, rect)
    -- rect: {x1,y1,x2,y2}  (all 1-based, inclusive)
    return x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4]
end

function M.collect_clicks(root)
    local hits = {}
    local function walk(n)
        if n.tag == "click" then
            local L = n.layout
            -- paint uses (floor(absX)+1, floor(absY)+1); do the same here
            local x1 = math.floor(L.absX) + 1 + (L.padding and L.padding[1] or 0)
            local y1 = math.floor(L.absY) + 1 + (L.padding and L.padding[2] or 0)
            local x2 = x1 + (L.w or 0) - 1
            local y2 = y1 + (L.h or 0) - 1
            hits[#hits + 1] = { node = n, rect = { x1, y1, x2, y2 }, on = n.attrs.on }
        end
        for _, c in ipairs(n.children or {}) do walk(c) end
    end
    walk(root)
    return hits
end

function M.dispatch(x, y, hits, handlers, state, rerender)
    for i = #hits, 1, -1 do
        local h = hits[i]
        if within(x, y, h.rect) then
            local fn = h.on and handlers and handlers[h.on]
            if type(fn) == "function" then
                fn({ x = x, y = y, node = h.node }, state, rerender)
                return true
            end
        end
    end
    return false
end

return M
