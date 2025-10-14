local styles = require("parser.style")


local M = {}


local function make_node(tag, attrs, style)
    return { tag = tag, attrs = attrs or {}, styles = style or {}, children = {}, layout = {} }
end


local function parse_attrs(attr)
    local attrs = {}
    for k, v in attr:gmatch("([%w%-]+)%s*=%s*\"(.-)\"") do attrs[k] = v end
    return attrs
end


function M.parse_markup(src)
    local root = make_node("col"); local stack = { root }; local i, iter = 1, 0
    while i <= #src do
        iter = iter + 1; if iter % 2000 == 0 then sleep(0) end
        if src:sub(i, i + 3) == "<!--" then
            local ci = src:find("%-%->", i + 4) or (#src - 2); i = ci + 3
        else
            local si, ei, closing, tag, attr = src:find("<%s*(/?)%s*([%w]+)([^>]*)>", i)
            if si == i and tag then
                local is_close = closing == "/"; local self_close = attr:match("/%s*$") ~= nil; i = ei + 1
                if is_close then
                    if #stack > 1 and stack[#stack].tag == tag then table.remove(stack) end
                else
                    local attrs = parse_attrs(attr)
                    -- KEEP the raw style string, then clear it from attrs:
                    local style_str = attrs.style
                    attrs.style = nil

                    local style = styles.parse_inline(style_str)
                    local node = make_node(tag, attrs, style)
                    table.insert(stack[#stack].children, node)
                    if tag == "text" then
                        local tsi, tei, inner = src:find("([%z\1-\255]-)</%s*text%s*>", i)
                        node.attrs._text = inner or ""; i = (tei and tei + 1) or i
                    elseif not self_close then
                        table.insert(stack, node)
                    end
                end
            else
                local next_tag = src:find("<", i + 1) or (#src + 1)
                local chunk = src:sub(i, next_tag - 1)
                if chunk:match("%S") then
                    local n = make_node("text", {}, {}); n.attrs._text = chunk
                    table.insert(stack[#stack].children, n)
                end
                i = next_tag
            end
        end
    end
    return root
end

return M
