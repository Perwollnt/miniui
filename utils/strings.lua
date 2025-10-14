local M = {}


function M.split_words(s)
    local w = {}; for x in (s or ""):gmatch("[^%s]+%s*") do w[#w + 1] = x end; return w
end

return M
