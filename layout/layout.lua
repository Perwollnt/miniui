-- miniui/layout/layout.lua
local units  = require("utils.units")
local styles = require("parser.style")

local M      = {}

local function wrap_text(split_words, s, width)
    width = math.max(0, width or 0); if width == 0 then return { "" } end
    local out = {}
    for raw in (tostring(s) .. "\n"):gmatch("(.-)\n") do
        local line = ""
        for _, tok in ipairs(split_words(raw)) do
            if #line + #tok <= width then
                line = line .. tok
            else
                if #line > 0 then out[#out + 1] = line end
                while #tok > width do
                    out[#out + 1] = tok:sub(1, width); tok = tok:sub(width + 1)
                end
                line = tok
            end
        end
        out[#out + 1] = line
    end
    return out
end

function M.measure(node, availW, availH, split_words)
    local st            = styles.to_units(node.computed)

    -- Box & colors
    node.layout.padding = st.padding
    node.layout.margin  = st.margin
    node.layout.gap     = st.gap
    node.layout.color   = st.color
    node.layout.bg      = st.bg

    node.layout.widthU  = st.widthU
    node.layout.heightU = st.heightU

    -- Inner box
    local pad           = node.layout.padding
    local innerW        = math.max(0, availW - pad[1] - pad[3])
    local innerH        = math.max(0, availH - pad[2] - pad[4])

    -- TEXT
    if node.tag == "text" then
        local w              = units.unit_to_px(node.layout.widthU, innerW, innerW)
        local lines          = wrap_text(require("utils.strings").split_words, node.attrs._text or "", w)
        node.layout.lines    = lines
        node.layout.contentW = w
        node.layout.contentH = #lines

    -- ROW: allocate widths as before + honor explicit child heights (abs/pct/auto)
    elseif node.tag == "row" then
        local fixedW, pctSumW = 0, 0
        local autosW = {}
        for _, c in ipairs(node.children or {}) do
            c.layout         = c.layout or {}
            c.layout.widthU  = units.parse_unit(c.computed.width or "auto")
            c.layout.heightU = units.parse_unit(c.computed.height or "auto")
            if c.layout.widthU.kind == "abs" then
                fixedW = fixedW + c.layout.widthU.v
            elseif c.layout.widthU.kind == "pct" then
                pctSumW = pctSumW + c.layout.widthU.v
            else
                autosW[#autosW + 1] = c
            end
        end
        local gapsW    = math.max(0, math.max(0, (#(node.children or {}) - 1)) * node.layout.gap)
        local usedPctW = math.floor(pctSumW * innerW + 0.5)
        local remainW  = math.max(0, innerW - fixedW - usedPctW - gapsW)
        local autoW    = (#autosW > 0) and math.floor(remainW / #autosW) or 0

        local x, maxH  = 0, 0
        for _, c in ipairs(node.children or {}) do
            local cw = (c.layout.widthU.kind == "abs" and c.layout.widthU.v)
                or (c.layout.widthU.kind == "pct" and math.floor(innerW * c.layout.widthU.v + 0.5))
                or autoW
            cw = units.clamp(cw, 0, innerW)

            local ch
            if c.layout.heightU.kind == "abs" then
                ch = c.layout.heightU.v
            elseif c.layout.heightU.kind == "pct" then
                ch = math.floor(innerH * c.layout.heightU.v + 0.5)
            else -- auto
                ch = innerH
            end
            ch = units.clamp(ch, 0, innerH)

            -- Measure with allocated height
            M.measure(c, cw, ch, split_words)

            -- MIN-HEIGHT: use at least the child's measured outer height
            local usedH = math.max(ch, c.layout.outerH)

            c.layout.x, c.layout.y = x, 0
            c.layout.w, c.layout.h = cw, usedH
            x = x + cw + node.layout.gap
            if usedH > maxH then maxH = usedH end
        end

        node.layout.contentW = innerW
        node.layout.contentH = maxH

    -- COL (default vertical stacking): allocate heights using abs/pct/auto
    else
        local kids = node.children or {}
        local fixedH, pctSumH = 0, 0
        local autos = {}

        for _, c in ipairs(kids) do
            c.layout = c.layout or {}
            c.layout.heightU = units.parse_unit(c.computed.height or "auto")
            if c.layout.heightU.kind == "abs" then
                fixedH = fixedH + c.layout.heightU.v
            elseif c.layout.heightU.kind == "pct" then
                pctSumH = pctSumH + c.layout.heightU.v
            else
                autos[#autos + 1] = c
            end
        end

        local gaps = math.max(0, math.max(0, (#kids - 1)) * node.layout.gap)
        local usedPct = math.floor(pctSumH * innerH + 0.5)
        local remaining = math.max(0, innerH - fixedH - usedPct - gaps)
        local autoH = (#autos > 0) and math.floor(remaining / #autos) or 0

        -- Precompute target heights so we can give rounding remainder to the last child
        local targets, sumT = {}, 0
        for idx, c in ipairs(kids) do
            local ch
            if c.layout.heightU.kind == "abs" then
                ch = c.layout.heightU.v
            elseif c.layout.heightU.kind == "pct" then
                ch = math.floor(innerH * c.layout.heightU.v + 0.5)
            else
                ch = autoH
            end
            ch = units.clamp(ch, 0, innerH)
            targets[idx] = ch
            sumT = sumT + ch
        end
        -- Give leftover cells to the last child so total fits exactly
        local remainder = math.max(0, innerH - (sumT + gaps))
        if #kids > 0 and remainder > 0 then
            targets[#kids] = targets[#kids] + remainder
        end

        local y, maxW, totalUsed = 0, 0, 0
        for i, c in ipairs(kids) do
            local ch = targets[i]
            M.measure(c, innerW, ch, split_words)

            -- MIN-HEIGHT: ensure at least the measured outer height
            local usedH = math.max(ch, c.layout.outerH)

            c.layout.x = 0; c.layout.y = y
            c.layout.w = c.layout.outerW; c.layout.h = usedH

            y = y + usedH + node.layout.gap
            totalUsed = totalUsed + usedH
            if c.layout.outerW > maxW then maxW = c.layout.outerW end
        end

        node.layout.contentW = maxW
        node.layout.contentH = math.max(0, totalUsed + (#kids > 1 and (#kids - 1) * node.layout.gap or 0))
    end

    -- Size this node (MIN-SIZE: never smaller than natural content)
    local contentW = node.layout.contentW or innerW
    local contentH = node.layout.contentH or innerH

    local naturalW = contentW + pad[1] + pad[3]
    local naturalH = contentH + pad[2] + pad[4]

    local wForced = units.unit_to_px(node.layout.widthU,  availW, naturalW)
    local hForced = units.unit_to_px(node.layout.heightU, availH, naturalH)

    local w = math.max(naturalW, wForced)
    local h = math.max(naturalH, hForced)

    node.layout.innerW = math.max(0, w - pad[1] - pad[3])
    node.layout.innerH = math.max(0, h - pad[2] - pad[4])
    node.layout.w, node.layout.h = w, h
    node.layout.outerW = w + node.layout.margin[1] + node.layout.margin[3]
    node.layout.outerH = h + node.layout.margin[2] + node.layout.margin[4]
end

function M.layout_tree(root, screenW, screenH)
    require("vdom.node").compute_styles(root, nil)
    M.measure(root, screenW, screenH, require("utils.strings").split_words)
    local function set_pos(n, ox, oy)
        n.layout.absX = ox + (n.layout.x or 0)
        n.layout.absY = oy + (n.layout.y or 0)
        for _, c in ipairs(n.children or {}) do
            set_pos(c, n.layout.absX + n.layout.padding[1], n.layout.absY + n.layout.padding[2])
        end
    end
    root.layout.x, root.layout.y = 0, 0
    root.layout.w, root.layout.h = root.layout.outerW, root.layout.outerH
    set_pos(root, 0, 0)
end

return M
