local reg = require("vdom.registry")
local style = require("parser.style")
local units = require("utils.units")


local Node = {}
Node.__index = Node


function Node.new(tag, props, children)
  local def = reg.get(tag)
  local s = {}
  if def and def.defaults then for k, v in pairs(def.defaults) do s[k] = v end end
  if props and props.style then for k, v in pairs(props.style) do s[k] = v end end

  local self = setmetatable({ tag = tag, attrs = props or {}, styles = s, children = {}, layout = {} }, Node)

  -- SPECIAL CASE: text nodes take string children as content
  if tag == "text" then
    -- If caller passed children, fold them into _text
    if children ~= nil then
      if type(children) == "table" then
        local acc = {}
        for _, c in ipairs(children) do acc[#acc+1] = tostring(c) end
        if #acc > 0 then self.attrs._text = (self.attrs._text or "") .. table.concat(acc) end
      else
        self.attrs._text = (self.attrs._text or "") .. tostring(children)
      end
    end
    return self
  end

  if children then
    for _, c in ipairs(children) do self:append(c) end
  end
  return self
end

function Node:text(str)
    self:append(Node.new("text", { _text = str }, nil)); return self
end

function Node:append(child)
  if self.tag == "text" then
    if type(child) == "table" and child.tag == "text" then
      self.attrs._text = (self.attrs._text or "") .. (child.attrs._text or "")
    else
      self.attrs._text = (self.attrs._text or "") .. tostring(child)
    end
    return self
  end
  if type(child) == "string" then child = Node.new("text", { _text = child }, nil) end
  table.insert(self.children, child)
  return self
end

function Node:setAttr(k, v)
    self.attrs[k] = v; return self
end

function Node:setStyle(k, v)
    self.styles[k] = v; return self
end

-- Compute inherited/composed styles
local INHERIT = { color = true }
local function compute_styles(node, parent)
    local def = reg.get(node.tag)
    local base = units.shallow_copy((def and def.defaults) or { display = "block" })
    for k, v in pairs(node.styles or {}) do base[k] = v end
    if parent then for k, _ in pairs(INHERIT) do if base[k] == nil and parent.computed and parent.computed[k] then base[k] =
                parent.computed[k] end end end
    node.computed = base
    for _, c in ipairs(node.children or {}) do compute_styles(c, node) end
end


Node.compute_styles = compute_styles


return Node
