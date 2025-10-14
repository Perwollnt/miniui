-- Simple Mustache-like text templater with partial imports
-- Supports: {{var}}, {{#cond}}...{{/cond}}, {{import "path"}}, {{.}}, {{#list}}...{{/list}}

local M = {}

-- basic variable lookup (supports nested: a.b.c)
local function lookup(ctx, key)
    if key == "." then return ctx["."] or ctx end
    local val = ctx
    for seg in key:gmatch("[^%.]+") do
        if type(val) ~= "table" then return nil end
        val = val[seg]
    end
    return val
end

-- template renderer (recursive)
local function render(str, ctx, opts)
    opts = opts or {}
    local base = opts.base or "."

    -- Handle {{import "file.html"}} (partial include)
    str = str:gsub("{{%s*import%s+\"([^\"]+)\"%s*}}", function(path)
        local full = fs.combine(base, path)
        if not fs.exists(full) then
            return ("[missing partial %s]"):format(path)
        end
        local h = fs.open(full, "r")
        local content = h.readAll()
        h.close()
        return render(content, ctx, { base = fs.getDir(full) })
    end)

    -- Handle {{#cond}}...{{/cond}} (conditional or list)
    str = str:gsub("{{#(.-)}}(.-){{/%1}}", function(key, inner)
        local val = lookup(ctx, key)
        if type(val) == "table" then
            local out = {}
            for _, item in ipairs(val) do
                local subctx = {}
                for k, v in pairs(ctx) do subctx[k] = v end
                subctx["."] = item
                table.insert(out, render(inner, subctx, opts))
            end
            return table.concat(out)
        elseif val then
            return render(inner, ctx, opts)
        else
            return ""
        end
    end)

    -- Handle {{var}}
    str = str:gsub("{{%s*([%w_%.]+)%s*}}", function(key)
        local val = lookup(ctx, key)
        if val == nil then return "" end
        return tostring(val)
    end)

    return str
end

function M.render(str, ctx, opts)
    return render(str, ctx or {}, opts or {})
end

M.tpl = M.render

return M
