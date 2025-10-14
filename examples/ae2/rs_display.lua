local UI = require("miniui/ui")
-- set your monitor names here
local target1 = "monitor_8"  -- main dashboard
local target2 = "monitor_2"  -- vertical percentage
local CHEST_NAME = "sophisticatedstorage:chest_0"

-- ---------- RS bridge ----------
local rs = peripheral.find("meBridge") or peripheral.find("me_bridge")
local mockRS = false
if not rs or type(rs.getItems) ~= "function" then
  print("RS Bridge: NOT found")
  rs = nil
  mockRS = true
else
  print("RS Bridge: found")
end

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

local function topMEExcluding(n, exclude, gridMap, meItems, orderDesc, searchValue)
  exclude  = exclude or {}
  gridMap  = gridMap or {}
  meItems  = meItems or {}
  n = tonumber(n) or 0

  -- Densify (ipairs keeps only 1..N)
  local list = {}
  for _, it in ipairs(meItems) do
    if it then list[#list+1] = it end
  end
  if #list < 2 then goto FILTER end

  -- Strict boolean comparator; never returns nil
  table.sort(list, function(a, b)
    local av = (a.amount or a.count or 0)
    local bv = (b.amount or b.count or 0)
    if orderDesc then return av > bv else return av < bv end
  end)

  ::FILTER::
  local sv = (type(searchValue) == "string") and searchValue or ""
  local want_all = (sv == "")
  local needle
  if not want_all then needle = sv:upper() end
  local out = {}

  for _, it in ipairs(list) do
    local id = it.name
    if id and not exclude[id] then
      local match = want_all
      if not match then
        local idUP   = string.upper(id)
        local dispUP = it.displayName and string.upper(it.displayName) or ""
        match = string.find(idUP, needle, 1, true) or string.find(dispUP, needle, 1, true)
      end
      if match then
        out[#out+1] = {
          id   = id,
          name = cleanName(it.displayName or id),
          amt  = gridMap[id] or (it.amount or it.count or 0),
        }
        if #out == n then break end
      end
    end
  end
  return out
end



-- ===== Snapshot from ME Bridge =====
local function fetchMEStatus(me)
  if mockRS then
    return {
      name = "MOCK ME",
      online = true,
      es = 5000000,
      ec = 10000000,
      usage = 20000,
      avgIn = 15000,
      ePct = 50,
      itTot = 100000,
      itUsed = 45000,
      itPct = 45,
      flTot = 50000,
      flUsed = 12000,
      flPct = 24,
      itemsIndexed = 1234,
      fluidsIndexed = 56,
      taskCount = 2,
      itemsList = {
        { name="minecraft:stone", amount=12345 },
        { name="minecraft:dirt", amount=6789 },
        { name="minecraft:cobblestone", amount=2345 },
        { name="minecraft:oak_log", amount=987 },
        { name="minecraft:iron_ore", amount=456 },
        { name="minecraft:gold_ore", amount=123 },
        { name="minecraft:diamond", amount=42 },
      }
    }
  end
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

local function fakeGetItems()
  return {
    { name="minecraft:stone", amount=12345 },
    { name="minecraft:dirt", amount=6789 },
    { name="minecraft:cobblestone", amount=2345 },
    { name="minecraft:oak_log", amount=987 },
    { name="minecraft:iron_ore", amount=456 },
    { name="minecraft:gold_ore", amount=123 },
    { name="minecraft:diamond", amount=42 },
  }
end

-- ===== Build the two columns =====
local function buildTwoColumns(inv, me, targetLinesPerScreen, orderDesc, searchValue)
  -- we want targetLinesPerScreen PER COLUMN
  local totalTarget = math.max(0, (targetLinesPerScreen or 40) * 2)

  local items = {}
  if mockRS then items = fakeGetItems() else items = me.getItems() or {} end

  local gridMap  = buildGridMap(items)
  local chestIDs = {name="asd", amount=3} -- dummy thingy
  if inv then chestIDs = readChestIdsOrdered(inv) end
  local lines, exclude = {}, {}

  for _, it in ipairs(chestIDs) do
    local amt = gridMap[it.id] or 0
    lines[#lines+1] = string.format("%s x%s", it.name, nfmt(amt))
    exclude[it.id] = true
    if #lines >= totalTarget then break end
  end

  local need = math.max(0, totalTarget - #lines)
  if need > 0 then
    local fill = topMEExcluding(need, exclude, gridMap, items, orderDesc, searchValue)
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
  local me   = rs
  local inv  = peripheral.wrap(CHEST_NAME) or peripheral.find("inventory");

  local mainMon = peripheral.wrap(target1)
  local targetLines = 40
  if mainMon and mainMon.getSize then
    local _, h = mainMon.getSize()
    targetLines = math.max(10, h - 4)
  end

  local s = fetchMEStatus(me)
  local orderDesc = state.orderDesc
  local left_text, middle_text = buildTwoColumns(inv, me, targetLines, orderDesc, state.input)

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
    input = state.input or "",
  }
  return data
end

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
  ltr_q   = function(_, s, rr) s.input = (s.input or "") .. "Q"; rr(); end,
  ltr_w   = function(_, s, rr) s.input = (s.input or "") .. "W"; rr(); end,
  ltr_e   = function(_, s, rr) s.input = (s.input or "") .. "E"; rr(); end,
  ltr_r   = function(_, s, rr) s.input = (s.input or "") .. "R"; rr(); end,
  ltr_t   = function(_, s, rr) s.input = (s.input or "") .. "T"; rr(); end,
  ltr_u   = function(_, s, rr) s.input = (s.input or "") .. "U"; rr(); end,
  ltr_i   = function(_, s, rr) s.input = (s.input or "") .. "I"; rr(); end,
  ltr_o   = function(_, s, rr) s.input = (s.input or "") .. "O"; rr(); end,
  ltr_p   = function(_, s, rr) s.input = (s.input or "") .. "P"; rr(); end,
  ltr_bps = function(_, s, rr) local t=s.input or ""; s.input=t:sub(1,#t-1); rr(); end,

  ltr_a   = function(_, s, rr) s.input = (s.input or "") .. "A"; rr(); end,
  ltr_s   = function(_, s, rr) s.input = (s.input or "") .. "S"; rr(); end,
  ltr_d   = function(_, s, rr) s.input = (s.input or "") .. "D"; rr(); end,
  ltr_f   = function(_, s, rr) s.input = (s.input or "") .. "F"; rr(); end,
  ltr_g   = function(_, s, rr) s.input = (s.input or "") .. "G"; rr(); end,
  ltr_h   = function(_, s, rr) s.input = (s.input or "") .. "H"; rr(); end,
  ltr_j   = function(_, s, rr) s.input = (s.input or "") .. "J"; rr(); end,
  ltr_k   = function(_, s, rr) s.input = (s.input or "") .. "K"; rr(); end,
  ltr_l   = function(_, s, rr) s.input = (s.input or "") .. "L"; rr(); end,

  ltr_y   = function(_, s, rr) s.input = (s.input or "") .. "Y"; rr(); end,
  ltr_x   = function(_, s, rr) s.input = (s.input or "") .. "X"; rr(); end,
  ltr_c   = function(_, s, rr) s.input = (s.input or "") .. "C"; rr(); end,
  ltr_v   = function(_, s, rr) s.input = (s.input or "") .. "V"; rr(); end,
  ltr_b   = function(_, s, rr) s.input = (s.input or "") .. "B"; rr(); end,
  ltr_n   = function(_, s, rr) s.input = (s.input or "") .. "N"; rr(); end,
  ltr_m   = function(_, s, rr) s.input = (s.input or "") .. "M"; rr(); end,
  ltr_spc = function(_, s, rr) s.input = (s.input or "") .. " "; rr(); end,
  ltr_mns = function(_, s, rr) s.input = (s.input or "") .. "-"; rr(); end,
}

local f = fs.open("screen_1.tpl","r"); local TPL1 = f.readAll(); f.close()
local f2 = fs.open("screen_2.tpl","r"); local TPL2 = f2.readAll(); f2.close()

screen1_terminal = peripheral.wrap(target1)
screen2_terminal = peripheral.wrap(target2)

local function view(state)
  local ctx = buildData(state)

  -- Render page with per-render bindings (two card instances → double-sub)
  local page = UI.tpl(TPL1, ctx, { base = "." })
  page = page:gsub("{{label}}", ctx.label or "", 1)
  page = page:gsub("{{value}}", ctx.value or "", 1)
  page = page:gsub("{{label}}", ctx.label2 or "", 1)
  page = page:gsub("{{value}}", ctx.value2 or "", 1)
  return page
end

local function view2(state)
  local ctx = buildData(state)
  -- Render page with per-render bindings (two card instances → double-sub)
  local page = UI.tpl(TPL2, ctx, { base = "." })
  page = page:gsub("{{label}}", ctx.label or "", 1)
  page = page:gsub("{{value}}", ctx.value or "", 1)
  page = page:gsub("{{label}}", ctx.label2 or "", 1)
  page = page:gsub("{{value}}", ctx.value2 or "", 1)
  return page
end

-- -------- main loop: render both screens --------
local state = { rand = math.random(0, 9999), tick = 0, orderDesc = true }

UI.run(view, screen1_terminal, handlers, state, {
  tick = 0.1,                                  -- repaint every second
  onTick = function(s) s.tick = s.tick + 1 end,
  afterRender = function(s)
    -- mirror the *same state* to the passive screen
    UI.render(view2(s), screen2_terminal)
    -- print("Tick", s.tick)
  end
})