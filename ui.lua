package.path = package.path .. ";./miniui/?.lua;./miniui/?/init.lua;./miniui/?/?.lua"

local tpl = require("tpl.template")
local markup = require("parser.markup")
local htmlshim = require("parser.html")
local reconcile = require("vdom.reconcile")
local Node = require("vdom.node")
local dispatch = require("events.dispatch")


local UI = {}

function UI.attach(any) return reconcile.attach(any) end

function UI.tpl(str, ctx, opts) return tpl.tpl(str, ctx, opts) end

function UI.render(markup_or_vdom, target)
    local root
    if type(markup_or_vdom) == "table" and markup_or_vdom.tag then
        root = markup_or_vdom
    else
        root = markup.parse_markup(markup_or_vdom)
    end
    local out = reconcile.render(root, target)
    out.hits = dispatch.collect_clicks(out.root)
    return out
end

function UI.renderFile(path, target)
    local f = fs.open(path, "r"); if not f then error("No such file: " .. tostring(path)) end
    local s = f.readAll(); f.close(); return UI.render(s, target)
end

function UI.htmlToMini(html) return htmlshim.htmlToMini(html) end

function UI.h(tag, props, children) return Node.new(tag, props or {}, children or {}) end

function UI.run(viewFn, target, handlers, state, opts)
  state, opts = state or {}, opts or {}
  local dispatch = require("events.dispatch")

  local function render_once()
    local view = viewFn(state)
    local result = UI.render(view, target)
    if opts.afterRender then opts.afterRender(state, result) end
    return result
  end

  local last = render_once()
  local tick = tonumber(opts.tick)
  local timer = tick and os.startTimer(tick) or nil

  while true do
    local ev, a, b, c = os.pullEvent()
    if ev == "monitor_touch" then
      dispatch.dispatch(b, c, last.hits, handlers, state, function() last = render_once() end)
    elseif ev == "mouse_click" then
      dispatch.dispatch(b, c, last.hits, handlers, state, function() last = render_once() end)
    elseif ev == "term_resize" then
      last = render_once()
    elseif ev == "timer" and timer and a == timer then
      if opts.onTick then opts.onTick(state) end
      last = render_once()
      timer = os.startTimer(tick)
    elseif ev == "ui_rerender" then
      last = render_once()
    end
  end
end

function UI.requestRerender()
  os.queueEvent("ui_rerender")
end

return UI
