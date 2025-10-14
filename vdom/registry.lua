local M = {}


-- Element registry: tag → { defaults, measure(node, availW, availH, ctx), render(node, win) }
local E = {}


function M.add(tag, def)
    E[tag] = def; return def
end

function M.get(tag) return E[tag] end

function M.all() return E end

M.add("col", { defaults = { display = "col", gap = "0", padding = "0" } })
M.add("row", { defaults = { display = "row", gap = "0", padding = "0" } })
M.add("box", { defaults = { display = "block", padding = "0" } })
M.add("text", { defaults = { display = "block", color = "white" } })
M.add("spacer", { defaults = { display = "block", width = "auto", height = "1" } })
M.add("click",{ defaults={ display="block", padding="0" } })


return M
