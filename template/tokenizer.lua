local M = {}

-- Splits template into text and directive tokens without heavy pattern churn.
function M.tokenize(src)
  local tokens = {}
  local i = 1
  local n = #src

  while i <= n do
    local open_i = src:find("{{", i, true)
    if not open_i then
      tokens[#tokens + 1] = { kind = "text", value = src:sub(i) }
      break
    end

    if open_i > i then
      tokens[#tokens + 1] = { kind = "text", value = src:sub(i, open_i - 1) }
    end

    local close_i = src:find("}}", open_i + 2, true)
    if not close_i then
      tokens[#tokens + 1] = { kind = "text", value = src:sub(open_i) }
      break
    end

    local body = src:sub(open_i + 2, close_i - 1)
    body = body:match("^%s*(.-)%s*$")
    tokens[#tokens + 1] = { kind = "tag", value = body }
    i = close_i + 2
  end

  return tokens
end

return M
