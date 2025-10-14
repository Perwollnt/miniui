-- v0.1: simple mount (no incremental diff yet). Future: keyed diff.
local layout = require("layout.layout")
local render = require("render.renderer")


local M = {}


function M.attach(any)
    if type(any) == "table" and any.write then return any end
    if type(any) == "string" then
        local p = peripheral.wrap(any)
        if p and peripheral.getType(any) == "monitor" then
            p.setTextScale(0.5); return p
        end
    end
    return term.current()
end

function M.render(rootNode, target)
    local t = M.attach(target)
    local w, h = t.getSize()
    local win = window.create(t, 1, 1, w, h, false)
    layout.layout_tree(rootNode, w, h)
    win.setVisible(false)
    render.paint(rootNode, win)
    win.setVisible(true)
    return { window = win, root = rootNode }
end

return M
