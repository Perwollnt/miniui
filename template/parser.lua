local expr = require("template.expr")

local M = {}

local function parse_directive(raw)
  if raw == "" then
    return { kind = "empty" }
  end
  local kw, rest = raw:match("^(%S+)%s*(.-)%s*$")
  if not kw then
    return { kind = "empty" }
  end

  if kw == "import" then
    local path = rest:match("^\"([^\"]+)\"$")
    if not path then
      return nil, "invalid import syntax: " .. raw
    end
    return { kind = "import", path = path }
  end

  if kw == "for" then
    return { kind = "for", raw = raw, header = rest }
  end

  if kw == "if" or kw == "elseif" or kw == "switch" or kw == "case" then
    if rest == "" then
      return nil, kw .. " requires an expression"
    end
    local c, err = expr.compile(rest)
    if not c then
      return nil, kw .. " expression error: " .. tostring(err)
    end
    return { kind = kw, expr = c, raw = raw }
  end

  if kw == "else" or kw == "default" or kw == "end" then
    return { kind = kw, raw = raw }
  end

  local output_expr, oerr = expr.compile(raw)
  if not output_expr then
    return nil, "output expression error: " .. tostring(oerr)
  end
  return { kind = "output", expr = output_expr, raw = raw }
end

local function parse_for_header(header)
  local h = header:match("^%s*(.-)%s*$")
  if h == "" then return nil, nil, nil, "invalid for syntax" end

  local key, val, source = h:match("^([%a_][%w_]*)%s*,%s*([%a_][%w_]*)%s+in%s+(.+)$")
  if key then return key, val, source, nil end

  val, source = h:match("^([%a_][%w_]*)%s+in%s+(.+)$")
  if val then return nil, val, source, nil end

  return nil, nil, nil, "invalid for header: " .. header
end

local function parse_block(tokens, idx, stop_kinds)
  local out = {}
  local n = #tokens

  while idx <= n do
    local t = tokens[idx]
    if t.kind == "text" then
      out[#out + 1] = { type = "Text", value = t.value }
      idx = idx + 1
    else
      local d, derr = parse_directive(t.value)
      if not d then
        return nil, idx, derr
      end

      if stop_kinds and stop_kinds[d.kind] then
        return out, idx, d
      end

      if d.kind == "empty" then
        idx = idx + 1
      elseif d.kind == "output" then
        out[#out + 1] = { type = "Output", expr = d.expr }
        idx = idx + 1
      elseif d.kind == "import" then
        out[#out + 1] = { type = "Import", path = d.path }
        idx = idx + 1
      elseif d.kind == "if" then
        local node = { type = "If", branches = {} }
        local cond = d.expr
        idx = idx + 1
        while true do
          local body, next_idx, stop = parse_block(tokens, idx, { ["elseif"] = true, ["else"] = true, ["end"] = true })
          if not body then return nil, next_idx, stop end
          node.branches[#node.branches + 1] = { cond = cond, body = body }
          idx = next_idx
          if not stop then
            return nil, idx, "if block missing end"
          end
          if stop.kind == "elseif" then
            cond = stop.expr
            idx = idx + 1
          elseif stop.kind == "else" then
            idx = idx + 1
            local else_body, end_idx, end_stop = parse_block(tokens, idx, { ["end"] = true })
            if not else_body then return nil, end_idx, end_stop end
            if not end_stop or end_stop.kind ~= "end" then
              return nil, end_idx, "if else block missing end"
            end
            node.else_body = else_body
            idx = end_idx + 1
            break
          else
            idx = idx + 1
            break
          end
        end
        out[#out + 1] = node
      elseif d.kind == "for" then
        local key_name, val_name, source, ferr = parse_for_header(d.header)
        if ferr then return nil, idx, ferr end
        local source_expr, src_err = expr.compile(source)
        if not source_expr then return nil, idx, "for source expression error: " .. tostring(src_err) end
        idx = idx + 1
        local body, next_idx, stop = parse_block(tokens, idx, { ["end"] = true })
        if not body then return nil, next_idx, stop end
        if not stop or stop.kind ~= "end" then
          return nil, next_idx, "for block missing end"
        end
        out[#out + 1] = {
          type = "For",
          key_name = key_name,
          val_name = val_name,
          source_expr = source_expr,
          body = body,
        }
        idx = next_idx + 1
      elseif d.kind == "switch" then
        idx = idx + 1
        local node = { type = "Switch", expr = d.expr, cases = {} }
        while idx <= n do
          local t2 = tokens[idx]
          if t2.kind == "text" then
            if t2.value:match("%S") then
              return nil, idx, "switch only allows case/default/end at top level"
            end
            idx = idx + 1
          elseif t2.kind ~= "tag" then
            return nil, idx, "switch expects case/default/end tags only"
          else
            local d2, d2err = parse_directive(t2.value)
            if not d2 then return nil, idx, d2err end

            if d2.kind == "case" then
              idx = idx + 1
              local body, next_idx, stop = parse_block(tokens, idx, { case = true, default = true, ["end"] = true })
              if not body then return nil, next_idx, stop end
              if not stop then return nil, next_idx, "switch case block missing end" end
              node.cases[#node.cases + 1] = { expr = d2.expr, body = body }
              idx = next_idx
              if stop.kind == "case" then
                -- continue loop; don't consume here
              elseif stop.kind == "default" then
                idx = idx + 1
                local def_body, end_idx, end_stop = parse_block(tokens, idx, { ["end"] = true })
                if not def_body then return nil, end_idx, end_stop end
                if not end_stop or end_stop.kind ~= "end" then
                  return nil, end_idx, "switch default block missing end"
                end
                node.default_body = def_body
                idx = end_idx + 1
                break
              else
                idx = idx + 1
                break
              end
            elseif d2.kind == "default" then
              idx = idx + 1
              local def_body, end_idx, end_stop = parse_block(tokens, idx, { ["end"] = true })
              if not def_body then return nil, end_idx, end_stop end
              if not end_stop or end_stop.kind ~= "end" then
                return nil, end_idx, "switch default block missing end"
              end
              node.default_body = def_body
              idx = end_idx + 1
              break
            elseif d2.kind == "end" then
              idx = idx + 1
              break
            else
              return nil, idx, "invalid switch directive: " .. tostring(d2.kind)
            end
          end
        end
        out[#out + 1] = node
      else
        return nil, idx, "unexpected directive: " .. tostring(d.kind)
      end
    end
  end

  return out, idx, nil
end

function M.parse(tokens)
  local body, idx, stop_or_err = parse_block(tokens, 1, nil)
  if not body then
    error("template parse error at token " .. tostring(idx) .. ": " .. tostring(stop_or_err))
  end
  if stop_or_err then
    error("template parse error: unexpected " .. tostring(stop_or_err.kind))
  end
  return { type = "Program", body = body }
end

return M

