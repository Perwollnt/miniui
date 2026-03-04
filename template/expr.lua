local M = {}
local NIL = {}

local PRECEDENCE = {
  ["or"] = 1,
  ["and"] = 2,
  ["=="] = 3, ["~="] = 3, ["<"] = 3, [">"] = 3, ["<="] = 3, [">="] = 3,
  [".."] = 4,
  ["+"] = 5, ["-"] = 5,
  ["*"] = 6, ["/"] = 6, ["%"] = 6,
}

local RIGHT_ASSOC = {
  [".."] = true,
}

-- I am fairly certain this could be better.
local function tokenize(src)
  local out = {}
  local i, n = 1, #src
  while i <= n do
    local ch = src:sub(i, i)

    if ch:match("%s") then
      i = i + 1
    elseif ch == "\"" or ch == "'" then
      local q = ch
      local j = i + 1
      local buf = {}
      while j <= n do
        local c = src:sub(j, j)
        if c == "\\" and j < n then
          local nx = src:sub(j + 1, j + 1)
          if nx == "n" then
            buf[#buf + 1] = "\n"
          elseif nx == "t" then
            buf[#buf + 1] = "\t"
          else
            buf[#buf + 1] = nx
          end
          j = j + 2
        elseif c == q then
          break
        else
          buf[#buf + 1] = c
          j = j + 1
        end
      end
      if j > n then
        return nil, "unterminated string literal"
      end
      out[#out + 1] = { t = "str", v = table.concat(buf) }
      i = j + 1
    else
      local two = src:sub(i, i + 1)
      local three = src:sub(i, i + 2)
      if two == "==" or two == "~=" or two == "<=" or two == ">=" or two == ".." then
        out[#out + 1] = { t = "op", v = two }
        i = i + 2
      elseif ch == "(" then
        out[#out + 1] = { t = "lp" }
        i = i + 1
      elseif ch == ")" then
        out[#out + 1] = { t = "rp" }
        i = i + 1
      elseif ch == "+" or ch == "-" or ch == "*" or ch == "/" or ch == "%" or ch == "<" or ch == ">" then
        out[#out + 1] = { t = "op", v = ch }
        i = i + 1
      elseif three == "and" and not src:sub(i + 3, i + 3):match("[%w_]") then
        out[#out + 1] = { t = "op", v = "and" }
        i = i + 3
      elseif two == "or" and not src:sub(i + 2, i + 2):match("[%w_]") then
        out[#out + 1] = { t = "op", v = "or" }
        i = i + 2
      elseif three == "not" and not src:sub(i + 3, i + 3):match("[%w_]") then
        out[#out + 1] = { t = "op", v = "not" }
        i = i + 3
      else
        local num = src:match("^%d+%.?%d*", i)
        if num then
          out[#out + 1] = { t = "num", v = tonumber(num) }
          i = i + #num
        else
          local id = src:match("^[%a_][%w_%.]*", i)
          if id then
            if id == "true" then
              out[#out + 1] = { t = "bool", v = true }
            elseif id == "false" then
              out[#out + 1] = { t = "bool", v = false }
            elseif id == "nil" then
              out[#out + 1] = { t = "nil" }
            else
              out[#out + 1] = { t = "id", v = id }
            end
            i = i + #id
          else
            return nil, "invalid token near `" .. src:sub(i, math.min(n, i + 12)) .. "`"
          end
        end
      end
    end
  end
  return out
end

local function to_rpn(tokens)
  local out, ops = {}, {}
  local prev_kind = "start"

  for i = 1, #tokens do
    local tk = tokens[i]
    if tk.t == "num" or tk.t == "str" or tk.t == "bool" or tk.t == "nil" or tk.t == "id" then
      out[#out + 1] = tk
      prev_kind = "value"
    elseif tk.t == "lp" then
      ops[#ops + 1] = tk
      prev_kind = "lp"
    elseif tk.t == "rp" then
      while #ops > 0 and ops[#ops].t ~= "lp" do
        out[#out + 1] = table.remove(ops)
      end
      if #ops == 0 then
        return nil, "mismatched parentheses"
      end
      table.remove(ops) -- remove lp
      prev_kind = "value"
    elseif tk.t == "op" then
      local op = tk.v
      if op == "-" and (prev_kind == "start" or prev_kind == "op" or prev_kind == "lp") then
        op = "u-"
      end
      if op == "not" then
        op = "u-not"
      end
      local prec = PRECEDENCE[op] or (op:sub(1, 2) == "u-" and 7) or 7
      local is_right = RIGHT_ASSOC[op] or op:sub(1, 2) == "u-"
      while #ops > 0 and ops[#ops].t == "op" do
        local top = ops[#ops].v
        local top_prec = PRECEDENCE[top] or (top:sub(1, 2) == "u-" and 7) or 7
        if (not is_right and prec <= top_prec) or (is_right and prec < top_prec) then
          out[#out + 1] = table.remove(ops)
        else
          break
        end
      end
      ops[#ops + 1] = { t = "op", v = op }
      prev_kind = "op"
    end
  end

  while #ops > 0 do
    local top = table.remove(ops)
    if top.t == "lp" then
      return nil, "mismatched parentheses"
    end
    out[#out + 1] = top
  end

  return out
end

local function truthy(v) return not (v == nil or v == false) end

local function lookup(state, id)
  if id == "." then return state.dot end
  local first = id:match("^[^%.]+")
  local rest = id:sub(#first + 1)

  local base = nil
  for i = #state.scopes, 1, -1 do
    local s = state.scopes[i]
    if s[first] ~= nil then
      base = s[first]
      break
    end
  end
  if base == nil and type(state.root) == "table" then
    base = state.root[first]
  end
  if rest == "" then return base end

  local cur = base
  for seg in rest:gmatch("%.([^%.]+)") do
    if type(cur) ~= "table" then return nil end
    local idx = tonumber(seg) or seg
    cur = cur[idx]
  end
  return cur
end

local function eval_rpn(rpn, state)
  local st = {}
  local function push(v)
    if v == nil then
      st[#st + 1] = NIL
    else
      st[#st + 1] = v
    end
  end
  local function pop()
    local v = st[#st]
    st[#st] = nil
    if v == NIL then return nil end
    return v
  end

  for i = 1, #rpn do
    local tk = rpn[i]
    if tk.t == "num" or tk.t == "str" or tk.t == "bool" then
      push(tk.v)
    elseif tk.t == "nil" then
      push(nil)
    elseif tk.t == "id" then
      push(lookup(state, tk.v))
    elseif tk.t == "op" then
      local op = tk.v
      if op == "u-" then
        local a = pop()
        push(-(tonumber(a) or 0))
      elseif op == "u-not" then
        local a = pop()
        push(not truthy(a))
      else
        local b = pop()
        local a = pop()
        if op == "+" then push((tonumber(a) or 0) + (tonumber(b) or 0))
        elseif op == "-" then push((tonumber(a) or 0) - (tonumber(b) or 0))
        elseif op == "*" then push((tonumber(a) or 0) * (tonumber(b) or 0))
        elseif op == "/" then push((tonumber(a) or 0) / (tonumber(b) or 1))
        elseif op == "%" then push((tonumber(a) or 0) % (tonumber(b) or 1))
        elseif op == ".." then push(tostring(a or "") .. tostring(b or ""))
        elseif op == "==" then push(a == b)
        elseif op == "~=" then push(a ~= b)
        elseif op == "<" then push((tonumber(a) or 0) < (tonumber(b) or 0))
        elseif op == ">" then push((tonumber(a) or 0) > (tonumber(b) or 0))
        elseif op == "<=" then push((tonumber(a) or 0) <= (tonumber(b) or 0))
        elseif op == ">=" then push((tonumber(a) or 0) >= (tonumber(b) or 0))
        elseif op == "and" then
          if truthy(a) then push(b) else push(a) end
        elseif op == "or" then
          if truthy(a) then push(a) else push(b) end
        else
          return nil, "unknown operator: " .. tostring(op)
        end
      end
    end
  end
  local last = st[#st]
  if last == NIL then return nil end
  return last
end

function M.compile(expr)
  expr = (expr or ""):match("^%s*(.-)%s*$")
  if expr == "" then
    return { kind = "const", value = nil }
  end
  if expr == "." then
    return { kind = "dot" }
  end
  local tokens, err = tokenize(expr)
  if not tokens then return nil, err end
  local rpn, err2 = to_rpn(tokens)
  if not rpn then return nil, err2 end
  return { kind = "rpn", rpn = rpn, src = expr }
end

function M.eval(compiled, state)
  if compiled.kind == "const" then return compiled.value end
  if compiled.kind == "dot" then return state.dot end
  return eval_rpn(compiled.rpn, state)
end

function M.truthy(v) return truthy(v) end

return M
