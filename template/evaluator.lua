local expr = require("template.expr")

local M = {}

local function each_table(tbl, fn)
  local n = #tbl
  if n > 0 then
    for i = 1, n do
      fn(i, tbl[i])
    end
    return
  end
  for k, v in pairs(tbl) do
    fn(k, v)
  end
end

local function eval_nodes(nodes, state, out, opts)
  for i = 1, #nodes do
    local n = nodes[i]
    if n.type == "Text" then
      out[#out + 1] = n.value
    elseif n.type == "Output" then
      local v = expr.eval(n.expr, state)
      if v ~= nil then out[#out + 1] = tostring(v) end
    elseif n.type == "Import" then
      local loader = opts.loader
      if loader and loader.render_import then
        out[#out + 1] = loader:render_import(n.path, state.root, opts, state)
      else
        out[#out + 1] = "[import loader missing: " .. n.path .. "]"
      end
    elseif n.type == "If" then
      local matched = false
      for bi = 1, #n.branches do
        local b = n.branches[bi]
        if expr.truthy(expr.eval(b.cond, state)) then
          eval_nodes(b.body, state, out, opts)
          matched = true
          break
        end
      end
      if not matched and n.else_body then
        eval_nodes(n.else_body, state, out, opts)
      end
    elseif n.type == "For" then
      local src = expr.eval(n.source_expr, state)
      if type(src) == "table" then
        local scope = {}
        state.scopes[#state.scopes + 1] = scope
        local prev_dot = state.dot
        each_table(src, function(k, v)
          if n.key_name then scope[n.key_name] = k end
          scope[n.val_name] = v
          scope["."] = v
          state.dot = v
          eval_nodes(n.body, state, out, opts)
          if n.key_name then scope[n.key_name] = nil end
          scope[n.val_name] = nil
          scope["."] = nil
        end)
        state.dot = prev_dot
        state.scopes[#state.scopes] = nil
      end
    elseif n.type == "Switch" then
      local base = expr.eval(n.expr, state)
      local matched = false
      for ci = 1, #n.cases do
        local c = n.cases[ci]
        if base == expr.eval(c.expr, state) then
          eval_nodes(c.body, state, out, opts)
          matched = true
          break
        end
      end
      if not matched and n.default_body then
        eval_nodes(n.default_body, state, out, opts)
      end
    else
      if opts.strict_control then
        error("unknown AST node: " .. tostring(n.type))
      end
    end
  end
end

function M.evaluate(ast, ctx, opts, inherited_state)
  opts = opts or {}
  local out = {}
  local state = inherited_state or {
    root = ctx or {},
    scopes = {},
    dot = ctx,
  }
  if not inherited_state then
    state.scopes[1] = ctx or {}
  end
  eval_nodes(ast.body or {}, state, out, opts)
  return table.concat(out)
end

return M

