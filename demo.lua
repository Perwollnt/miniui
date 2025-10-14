-- demo.lua (percent heights; responsive; no overflow; monitor-first)
package.path = package.path .. ";./miniui/?.lua;./miniui/?/init.lua;./miniui/?/?.lua"

local UI = require("ui")

-- pick monitor if present
local function pickTarget()
  if peripheral and peripheral.getNames then
    for _, name in ipairs(peripheral.getNames()) do
      if peripheral.getType(name) == "monitor" then
        local mon = peripheral.wrap(name)
        if mon then
          mon.setTextScale(0.5); return mon
        end
      end
    end
  end
  if peripheral and peripheral.find then
    local mon = peripheral.find("monitor")
    if mon then
      mon.setTextScale(0.5); return mon
    end
  end
  return term.current()
end

local target = pickTarget()
local W, H   = target.getSize()
local NARROW = W < 50  -- switch to one column
local SHORT  = H <= 19 -- tighter vertical budget

-- ensure partials
if not fs.exists("partials") then fs.makeDir("partials") end

-- header
do
  local f = fs.open("partials/header.html", "w"); f.write([[
<box style="bg:blue; padding:1; height:{{headerH}}">
  <text style="color:white">{{title}}</text>
</box>]]); f.close()
end

-- hero
do
  local f = fs.open("partials/hero.html", "w"); f.write([[
<box style="bg:purple; padding:1; height:{{heroH}}">
  <text style="color:white">{{heroLine}}</text>
</box>]]); f.close()
end

-- card (no margins; padding only)
do
  local f = fs.open("partials/card.html", "w"); f.write([[
<box style="padding:1; bg:gray">
  <text style="color:lightBlue">{{label}}</text>
  <text style="color:white">{{value}}</text>
</box>]]); f.close()
end

-- list (no margins; padding only)
do
  local f = fs.open("partials/list.html", "w"); f.write([[
<box style="padding:1; bg:brown">
  <text style="color:yellow">{{heading}}</text>
  {{#items}}<text>- {{.}}</text>{{/items}}
</box>]]); f.close()
end

-- footer
do
  local f = fs.open("partials/footer.html", "w"); f.write([[
<box style="bg:gray; padding:1; height:{{footerH}}">
  <text style="color:lightBlue">Updated: {{time}}</text>
</box>]]); f.close()
end

-- page: every top-level section has a % height (leaving slack for gaps/padding).
local page_tpl = [[
<col style="gap:1; padding:1; bg:black; height:100%">
  {{import "partials/header.html"}}
  {{import "partials/hero.html"}}

  {{#twoCol}}
  <row style="gap:1; height:{{contentH}}">
    <!-- Left column: two cards that fit with one internal gap -->
    <box style="width:50%; height:100%">
      <col style="gap:1; height:100%">
        <!-- Make the cards clickable -->
        <click on="inc"   style="height:48%">{{import "partials/card.html"}}</click>
        <click on="reset" style="height:48%">{{import "partials/card.html"}}</click>
      </col>
    </box>
    <!-- Right column: list fills the column -->
    <box style="width:50%; height:100%">
      <box style="height:100%">{{import "partials/list.html"}}</box>
    </box>
  </row>
  {{/twoCol}}

  {{#oneCol}}
  <col style="gap:1; height:{{contentH}}">
    <text style="color:yellow">Count: {{count}}</text>
    <box style="height:38%">{{import "partials/card.html"}}</box>
    <box style="height:24%">{{import "partials/card.html"}}</box>
    <box style="height:38%">{{import "partials/list.html"}}</box>
  </col>
  {{/oneCol}}

  {{import "partials/footer.html"}}
</col>
]]

-- helpers
local function now_str()
  local ok, s = pcall(function()
    if textutils and textutils.formatTime then return textutils.formatTime(os.time(), true) end
  end)
  return (ok and s) or string.format("%.2f", os.clock())
end

-- Compute safe section percentages (sum <= 94% so there’s slack for rounding/padding)
local HEADER_PCT  = SHORT and 0.12 or 0.11
local HERO_PCT    = SHORT and 0.12 or 0.13
local FOOTER_PCT  = SHORT and 0.12 or 0.11
local CONTENT_PCT = 0.94 - (HEADER_PCT + HERO_PCT + FOOTER_PCT)
-- Convert to strings for the template
local function pct(n) return string.format("%d%%", math.floor(n * 100 + 0.5)) end

-- Estimate how many list rows will fit without overflow
local function list_capacity()
  -- inner height ≈ H * CONTENT_PCT minus:
  -- - root padding (2 rows, approx), section gaps (≈3), list header (1), a bit of slack
  local approx = math.floor(H * CONTENT_PCT) - 6
  if NARROW then approx = approx - 1 end
  return math.max(3, math.min(10, approx))
end

local function view(state)
  local maxItems = list_capacity()
  local items = {}
  for i = 1, maxItems do items[i] = tostring(math.random(100, 999)) end

  local ctx = {
    -- layout toggles
    twoCol   = not NARROW,
    oneCol   = NARROW,

    -- section heights
    headerH  = pct(HEADER_PCT),
    heroH    = pct(HERO_PCT),
    contentH = pct(CONTENT_PCT),
    footerH  = pct(FOOTER_PCT),

    -- text
    title    = "Live Stats",
    heroLine = "Welcome, " .. (os.getComputerLabel() or ("Computer #" .. os.getComputerID())),

    -- cards (drive from state so clicks are visible)
    label    = (NARROW and "Rand" or "Random number"),
    value    = tostring(state.rand or 0),
    label2   = (NARROW and "Tick" or "Tick count"),
    value2   = tostring(state.tick or 0),

    -- list
    heading  = (NARROW and "Recent" or "Recent values"),
    items    = items,

    -- footer
    time     = now_str(),
  }

  -- Render page with per-render bindings (two card instances → double-sub)
  local page = UI.tpl(page_tpl, ctx, { base = "." })
  page = page:gsub("{{label}}", ctx.label, 1)
  page = page:gsub("{{value}}", ctx.value, 1)
  page = page:gsub("{{label}}", ctx.label2, 1)
  page = page:gsub("{{value}}", ctx.value2, 1)
  return page
end

-- Click handlers for the <click on="..."> tags
local handlers = {
  inc = function(_, state, rerender)
    state.rand = (state.rand or 0) + math.random(1, 99)
    rerender()
  end,
  reset = function(_, state, rerender)
    state.rand = 0
    state.tick = 0
    rerender()
  end,
}

-- App state + background ticker
local state = { rand = math.random(0, 9999), tick = 0 }

UI.run(view, target, handlers, state, {
  tick = 1,                                  -- repaint every second
  onTick = function(s) s.tick = s.tick + 1 end,
  afterRender = function(s)
    -- UI.render(view2(s), screen2_terminal)
    print("Tick", s.tick)
  end
})