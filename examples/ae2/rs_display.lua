local UI = require("miniui/ui")
-- set your monitor names here
local target1 = "monitor_8"  -- main dashboard
local target2 = "monitor_2"  -- vertical percentage
local CHEST_NAME = "sophisticatedstorage:chest_0"

-- ---------- RS bridge ----------
local rs = peripheral.find("me_bridge") or peripheral.find("mebridge")
assert(rs, "ME Bridge not found")

-- ===== Formatting & small helpers =====
local function cleanName(s)
  s = s or ""
  s = s:gsub("[%[%]]","")     -- drop [ ]
  s = s:gsub("^.+:", "")      -- drop mod id prefix
  return s
end

local function nfmt(n)
  n = tonumber(n) or 0
  if n >= 1e9 then return string.format("%.1fb", n/1e9)
  elseif n >= 1e6 then return string.format("%.1fm", n/1e6)
  elseif n >= 1e3 then return string.format("%.1fk", n/1e3)
  else return tostring(n) end
end

local function pct(a,b)
  if not b or b <= 0 then return 0 end
  return math.max(0, math.min(100, math.floor((a/b)*100 + 0.5)))
end

-- ===== Chest-first ordering =====
local function readChestIdsOrdered(inv)
  local seen, out = {}, {}
  local listed = inv.list and inv.list() or {}
  local size = (inv.size and inv.size()) or 54
  for slot = 1, size do
    local it = listed[slot]
    if it and it.name and not seen[it.name] then
      seen[it.name] = true
      out[#out+1] = { id = it.name, name = cleanName(it.displayName or it.name) }
    end
  end
  return out
end

local function buildGridMap(meItems)
  local m = {}
  for _, it in ipairs(meItems or {}) do
    m[it.name] = (it.amount or it.count or 0)
  end
  return m
end

local function topMEExcluding(n, exclude, gridMap, meItems, orderDesc)
  local list = { table.unpack(meItems or {}) }
  if orderDesc then
    table.sort(list, function(a,b) return (a.amount or a.count or 0) > (b.amount or b.count or 0) end)
  else
    table.sort(list, function(a,b) return (a.amount or a.count or 0) < (b.amount or b.count or 0) end)
  end
  local out = {}
  for _, it in ipairs(list) do
    local id = it.name
    if id and not exclude[id] then
      out[#out+1] = {
        id = id,
        name = cleanName(it.displayName or id),
        amt = gridMap[id] or (it.amount or it.count or 0)
      }
      if #out == n then break end
    end
  end
  return out
end

-- ===== Snapshot from ME Bridge =====
local function fetchMEStatus(me)
  local s = {}
  s.name   = (me.getName and me.getName()) or "ME"
  s.online = (me.isOnline and me.isOnline()) or (me.isConnected and me.isConnected()) or true

  -- Energy
  s.es     = me.getStoredEnergy() or 0
  s.ec     = me.getEnergyCapacity() or 0
  s.usage  = me.getEnergyUsage() or 0
  s.avgIn  = me.getAverageEnergyInput and (me.getAverageEnergyInput() or 0) or 0
  s.ePct   = pct(s.es, s.ec)

  -- Storage (internal)
  s.itTot  = me.getTotalItemStorage() or 0
  s.itUsed = me.getUsedItemStorage() or 0
  s.itPct  = pct(s.itUsed, s.itTot)

  s.flTot  = me.getTotalFluidStorage() or 0
  s.flUsed = me.getUsedFluidStorage() or 0
  s.flPct  = pct(s.flUsed, s.flTot)

  -- Counts (index sizes)
  local itList = me.getItems() or {}
  local flList = me.getFluids and (me.getFluids() or {}) or {}
  s.itemsIndexed  = #itList
  s.fluidsIndexed = #flList

  -- Crafting
  local tasks = me.getCraftingTasks and (me.getCraftingTasks() or {}) or {}
  s.taskCount = #tasks

  -- Provide items list for chest-first merge
  s.itemsList = itList

  return s
end

-- ===== Build the two columns =====
local function buildTwoColumns(inv, me, targetLinesPerScreen, orderDesc)
  -- we want targetLinesPerScreen PER COLUMN
  local totalTarget = math.max(0, (targetLinesPerScreen or 40) * 2)

  local gridMap  = buildGridMap(me.getItems() or {})
  local chestIDs = readChestIdsOrdered(inv)
  local lines, exclude = {}, {}

  for _, it in ipairs(chestIDs) do
    local amt = gridMap[it.id] or 0
    lines[#lines+1] = string.format("%s x%s", it.name, nfmt(amt))
    exclude[it.id] = true
    if #lines >= totalTarget then break end
  end

  local need = math.max(0, totalTarget - #lines)
  if need > 0 then
    local meList = me.getItems() or {}
    local fill = topMEExcluding(need, exclude, gridMap, meList, orderDesc)
    for _, it in ipairs(fill) do
      lines[#lines+1] = string.format("%s x%s", it.name, nfmt(it.amt))
      if #lines >= totalTarget then break end
    end
  end

  local count = math.min(#lines, totalTarget)
  local mid   = math.ceil(count / 2)
  local left_lines   = table.concat({table.unpack(lines, 1,     mid)}, "\n")
  local middle_lines = table.concat({table.unpack(lines, mid+1, count)}, "\n")


  if orderDesc then
    left_lines, middle_lines = left_lines, middle_lines 
  else
    -- invert the order
  end

  return left_lines, middle_lines
end

local floatFormat = "%.1f"

-- ===== Public: buildData() =====
local function buildData(state)
  local me   = peripheral.find("me_bridge") or peripheral.find("meBridge") or error("me_bridge not found")
  local inv  = peripheral.wrap(CHEST_NAME) or peripheral.find("inventory") or error("chest not found")

  local mainMon = peripheral.wrap(target1)
  local targetLines = 40
  if mainMon and mainMon.getSize then
    local _, h = mainMon.getSize()
    targetLines = math.max(10, h - 4)
  end

  local s = fetchMEStatus(me)
  local orderDesc = state.orderDesc
  local left_text, middle_text = buildTwoColumns(inv, me, targetLines, orderDesc)

  local data = {
    left_list   = left_text,
    middle_list = middle_text,

    status = s.online and "ONLINE" or "OFFLINE",

    energy = {
      used = nfmt(s.es),
      cap  = nfmt(s.ec),
      pct  = s.ePct,
      -- format floating point number with 1 decimal place
      net  = (string.format(floatFormat, nfmt( (s.avgIn or 0) - (s.usage or 0) ))),
    },

    items = {
      used = nfmt(s.itUsed),
      cap  = nfmt(s.itTot),
      pct  = s.itPct,
    },

    fluids = {
      used = nfmt(s.flUsed),
      cap  = nfmt(s.flTot),
      pct  = s.flPct,
    },

    craft = {
      tasks = s.taskCount or 0,
    },

    big = {
      pct = s.itPct,
      max = 100 - s.itPct,
    },
    rand = state.rand or 0,
  }
  return data
end

screen1_terminal = peripheral.wrap(target1)
screen2_terminal = peripheral.wrap(target2)

local handlers = {
  inc = function(_, state, rerender)
    state.rand = (state.rand or 0) + math.random(1, 99)
    state.orderDesc = not state.orderDesc
    rerender()
  end,
  reset = function(_, state, rerender)
    state.rand = 0
    state.tick = 0
    rerender()
  end,
}

local function view(state)
  local ctx = buildData(state)

  local file = fs.open("screen_1.tpl", "r")
  local page_tpl = file.readAll()
  file.close()

  -- Render page with per-render bindings (two card instances → double-sub)
  local page = UI.tpl(page_tpl, ctx, { base = "." })
  page = page:gsub("{{label}}", ctx.label, 1)
  page = page:gsub("{{value}}", ctx.value, 1)
  page = page:gsub("{{label}}", ctx.label2, 1)
  page = page:gsub("{{value}}", ctx.value2, 1)
  return page
end

local function view2(state)
  local ctx = buildData(state)

  local file = fs.open("screen_2.tpl", "r")
  local page_tpl = file.readAll()
  file.close()

  -- Render page with per-render bindings (two card instances → double-sub)
  local page = UI.tpl(page_tpl, ctx, { base = "." })
  page = page:gsub("{{label}}", ctx.label, 1)
  page = page:gsub("{{value}}", ctx.value, 1)
  page = page:gsub("{{label}}", ctx.label2, 1)
  page = page:gsub("{{value}}", ctx.value2, 1)
  return page
end

-- -------- main loop: render both screens --------
local state = { rand = math.random(0, 9999), tick = 0, orderDesc = true }

UI.run(view, screen1_terminal, handlers, state, {
  tick = 1,                                  -- repaint every second
  onTick = function(s) s.tick = s.tick + 1 end,
  afterRender = function(s)
    -- mirror the *same state* to the passive screen
    UI.render(view2(s), screen2_terminal)
    -- print("Tick", s.tick)
  end
})