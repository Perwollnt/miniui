local colors = require("utils.color")


local M = {}


local function fill_rect_term(win, x, y, w, h, bg)
    local oldBG = win.getBackgroundColor()
    win.setBackgroundColor(bg or colors.DEFAULT_BG)
    local blank = string.rep(" ", w)
    for yy = y, y + h - 1 do
        win.setCursorPos(x, yy); win.write(blank)
    end
    win.setBackgroundColor(oldBG)
end


local function write_row_term(win, x, y, s, fg, bg)
    local oldFG, oldBG = win.getTextColor(), win.getBackgroundColor()
    if bg then win.setBackgroundColor(bg) end
    if fg then win.setTextColor(fg) end
    win.setCursorPos(x, y); win.write(s)
    win.setTextColor(oldFG); win.setBackgroundColor(oldBG)
end


function M.paint(node, win)
    local L = node.layout
    local absX, absY = math.floor(L.absX) + 1, math.floor(L.absY) + 1
    local w, h = L.w, L.h
    if L.bg then fill_rect_term(win, absX, absY, w, h, L.bg) end
    if node.tag == "text" then
        local lines = L.lines or { node.attrs._text or "" }
        for i = 1, math.min(#lines, L.innerH) do
            write_row_term(win, absX + L.padding[1], absY + L.padding[2] + i - 1, lines[i], L.color, L.bg)
        end
    end
    for _, c in ipairs(node.children or {}) do M.paint(c, win) end
end

return M
