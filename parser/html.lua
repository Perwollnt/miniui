local M = {}
function M.htmlToMini(html)
    local s = html
    s = s:gsub("<br%s*/?>", "\n")
    s = s:gsub("</%s*p%s*>", "</text>")
    s = s:gsub("<%s*p(.-)>", "<text%1>")
    s = s:gsub("</%s*div%s*>", "</box>")
    s = s:gsub("<%s*div(.-)>", "<box%1>")
    s = s:gsub("</%s*span%s*>", "</text>")
    s = s:gsub("<%s*span(.-)>", "<text%1>")
    s = s:gsub("</?%s*b%s*>", ""):gsub("</?%s*i%s*>", "")
    return "<col>" .. s .. "</col>"
end

return M
