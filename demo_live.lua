local running = (shell and shell.getRunningProgram and shell.getRunningProgram()) or "demo_live.lua"
local here = fs.getDir(running)
if here == "" then here = "." end
local miniui_root = here
if shell and shell.resolve then
  miniui_root = shell.resolve(miniui_root)
end

local ui_path = fs.combine(miniui_root, "ui.lua")
_G.__MINIUI_ROOT = miniui_root
local UI
if fs.exists(ui_path) then
  UI = dofile(ui_path)
elseif type(require) == "function" then
  UI = require("ui")
else
  error("ui.lua not found and require() unavailable")
end
local V2 = UI and (UI.v2 or UI)

local source = fs.combine(miniui_root, "examples/live/storage_page.ui")
local target = ...

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function comma_num(n)
  local s = tostring(math.floor(tonumber(n) or 0))
  local sign = ""
  if s:sub(1, 1) == "-" then
    sign = "-"
    s = s:sub(2)
  end
  -- Format groups from the right without a growth loop.
  local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
  if out:sub(1, 1) == "," then
    out = out:sub(2)
  end
  return sign .. out
end

local function ellipsize(s, max_len)
  s = tostring(s or "")
  local m = math.max(4, math.floor(tonumber(max_len) or 12))
  if #s <= m then return s end
  return s:sub(1, m - 3) .. "..."
end

local function get_target_size(target_name)
  if target_name and peripheral and peripheral.wrap then
    local p = peripheral.wrap(target_name)
    if p and p.getSize then
      local w, h = p.getSize()
      if w and h then return w, h end
    end
  end
  if term and term.getSize then
    local w, h = term.getSize()
    if w and h then return w, h end
  end
  return 39, 19
end

local function make_bar(used, capacity, width)
  local cap = math.max(1, tonumber(capacity) or 1)
  local pct = clamp((tonumber(used) or 0) / cap, 0, 1)
  local w = clamp(math.floor(width or 12), 8, 36)
  local filled = clamp(math.floor(pct * w + 0.5), 0, w)
  return string.rep("#", filled) .. string.rep(".", w - filled), math.floor(pct * 100 + 0.5)
end

local function sorted_copy(items)
  local out = {}
  for i = 1, #items do out[i] = items[i] end
  table.sort(out, function(a, b)
    if (a.qty or 0) == (b.qty or 0) then
      return (a.name or "") < (b.name or "")
    end
    return (a.qty or 0) > (b.qty or 0)
  end)
  return out
end

local function sorted_rows(rows)
  local out = {}
  for i = 1, #rows do out[i] = rows[i] end
  table.sort(out, function(a, b)
    if (a.qty_num or 0) == (b.qty_num or 0) then
      return (a.name or "") < (b.name or "")
    end
    return (a.qty_num or 0) > (b.qty_num or 0)
  end)
  return out
end

local function sorted_rows_by_mode(rows, mode)
  local out = {}
  for i = 1, #rows do out[i] = rows[i] end
  if mode == "abc" then
    table.sort(out, function(a, b)
      return (a.name or "") < (b.name or "")
    end)
  else
    table.sort(out, function(a, b)
      if (a.qty_num or 0) == (b.qty_num or 0) then
        return (a.name or "") < (b.name or "")
      end
      return (a.qty_num or 0) > (b.qty_num or 0)
    end)
  end
  return out
end

local MockStorageAPI = {}

MockStorageAPI.storages = {
  {
    id = "ae2-main",
    name = "ME Drive Alpha (Applied Energistics 2)",
    item_capacity = 16384,
    fluid_capacity = 128000,
    gas_capacity = 96000,
    item_used_base = 11120,
    fluid_used_base = 72000,
    gas_used_base = 44500,
    items = {
      { name = "Cobblestone", qty = 12034 },
      { name = "Iron Ingot", qty = 4032 },
      { name = "Redstone Dust", qty = 1928 },
      { name = "Applied Processor", qty = 1280 },
      { name = "Certus Quartz", qty = 993 },
      { name = "Diamond", qty = 488 },
      { name = "Fluix Crystal", qty = 412 },
      { name = "Glowstone Dust", qty = 244 },
      { name = "Charged Certus", qty = 139 },
      { name = "Ender Pearl", qty = 92 },
    },
    fluids = {
      { name = "Water Cell", qty = 36000 },
      { name = "Lava Cell", qty = 20500 },
      { name = "Liquid XP Cell", qty = 9300 },
    },
    gases = {
      { name = "Hydrogen Capsule", qty = 19000 },
      { name = "Oxygen Capsule", qty = 12400 },
      { name = "Chlorine Capsule", qty = 4800 },
    },
  },
  {
    id = "rs-factory",
    name = "Refined Storage Network (Factory)",
    item_capacity = 32768,
    fluid_capacity = 256000,
    gas_capacity = 64000,
    item_used_base = 22550,
    fluid_used_base = 148000,
    gas_used_base = 25200,
    items = {
      { name = "Stone", qty = 23120 },
      { name = "Steel Ingot", qty = 8120 },
      { name = "Copper Ingot", qty = 6405 },
      { name = "Machine Casing", qty = 2204 },
      { name = "Quartz Enriched Iron", qty = 1771 },
      { name = "Nether Quartz", qty = 944 },
      { name = "Silicon", qty = 533 },
      { name = "Printed Circuit", qty = 377 },
      { name = "Storage Part", qty = 156 },
      { name = "Speed Upgrade", qty = 81 },
    },
    fluids = {
      { name = "Coolant Drum", qty = 98000 },
      { name = "Biofuel Drum", qty = 30500 },
      { name = "Steam Drum", qty = 18800 },
    },
    gases = {
      { name = "Ethylene Capsule", qty = 17100 },
      { name = "Lithium Capsule", qty = 5600 },
      { name = "Deuterium Capsule", qty = 2500 },
    },
  },
  {
    id = "mek-qio",
    name = "QIO Array (Mekanism)",
    item_capacity = 65536,
    fluid_capacity = 512000,
    gas_capacity = 192000,
    item_used_base = 41000,
    fluid_used_base = 266000,
    gas_used_base = 110500,
    items = {
      { name = "Netherrack", qty = 31200 },
      { name = "Gold Ingot", qty = 11120 },
      { name = "Osmium Ingot", qty = 9300 },
      { name = "Uranium Ingot", qty = 6020 },
      { name = "Refined Obsidian", qty = 2014 },
      { name = "HDPE Pellet", qty = 1622 },
      { name = "Polonium Pellet", qty = 412 },
      { name = "Antimatter Pellet", qty = 149 },
      { name = "Teleportation Core", qty = 94 },
      { name = "Ultimate Control Circuit", qty = 72 },
    },
    fluids = {
      { name = "Sodium Coolant Cell", qty = 185000 },
      { name = "Brine Cell", qty = 52000 },
      { name = "Heavy Water Cell", qty = 22100 },
    },
    gases = {
      { name = "Hydrogen Capsule", qty = 53000 },
      { name = "Sulfur Dioxide Capsule", qty = 30100 },
      { name = "Nuclear Waste Capsule", qty = 12900 },
    },
  },
}

function MockStorageAPI.list()
  return MockStorageAPI.storages
end

function MockStorageAPI.get_snapshot(index, tick)
  local base = MockStorageAPI.storages[index] or MockStorageAPI.storages[1]
  local t = tonumber(tick) or 0
  local function wobble(v, spread, maxv, salt)
    local shifted = v + math.sin((t + salt) * 0.55) * spread
    return clamp(math.floor(shifted + 0.5), 0, maxv)
  end
  return {
    id = base.id,
    name = base.name,
    item_capacity = base.item_capacity,
    fluid_capacity = base.fluid_capacity,
    gas_capacity = base.gas_capacity,
    item_used = wobble(base.item_used_base, 750, base.item_capacity, 1),
    fluid_used = wobble(base.fluid_used_base, 12000, base.fluid_capacity, 2),
    gas_used = wobble(base.gas_used_base, 9000, base.gas_capacity, 3),
    items = base.items,
    fluids = base.fluids,
    gases = base.gases,
  }
end

local state = {
  version = 1,
  tick = 0,
  storage_idx = 1,
  sort_mode = "amount",
  storages = MockStorageAPI.list(),
}

local function bump(s)
  s.version = s.version + 1
end

local function rerender_after(handler)
  return function(payload, s, rerender)
    handler(payload, s)
    bump(s)
    rerender()
  end
end

local handlers = {
  next_storage = rerender_after(function(_, s)
    s.storage_idx = (s.storage_idx % #s.storages) + 1
  end),
  prev_storage = rerender_after(function(_, s)
    s.storage_idx = ((s.storage_idx - 2 + #s.storages) % #s.storages) + 1
  end),
  refresh = rerender_after(function(_, s)
    s.tick = s.tick + 1
  end),
  toggle_sort = rerender_after(function(payload, s)
    -- Toggle on any click/touch in this panel (monitor has no right-click event type).
    if payload then
      if s.sort_mode == "abc" then
        s.sort_mode = "amount"
      else
        s.sort_mode = "abc"
      end
    end
  end),
}

print("miniui storage demo")
print("Source:", source)
print("Edit the source/partials in VS Code and save to live reload.")

V2.runLive({
  source = source,
  target = target,
  state = state,
  handlers = handlers,
  pollInterval = 0.25,
  contextProvider = function(s)
    local screen_w, screen_h = get_target_size(target)
    local compact = screen_w < 36 or screen_h < 16
    local snapshot = MockStorageAPI.get_snapshot(s.storage_idx, s.tick)
    local bar_w = clamp(math.floor(screen_w * (compact and 0.35 or 0.45)), 8, 26)
    local item_bar, item_pct = make_bar(snapshot.item_used, snapshot.item_capacity, bar_w)
    local fluid_bar, fluid_pct = make_bar(snapshot.fluid_used, snapshot.fluid_capacity, bar_w)
    local gas_bar, gas_pct = make_bar(snapshot.gas_used, snapshot.gas_capacity, bar_w)

    local combined_rows = {}
    for i = 1, #snapshot.items do
      local it = snapshot.items[i]
      combined_rows[#combined_rows + 1] = {
        name = ellipsize(it.name, compact and 18 or 38),
        qty = comma_num(it.qty),
        qty_num = it.qty,
        color = "white",
      }
    end
    for i = 1, #snapshot.fluids do
      local it = snapshot.fluids[i]
      combined_rows[#combined_rows + 1] = {
        name = ellipsize(it.name, compact and 16 or 28),
        qty = comma_num(it.qty),
        qty_num = it.qty,
        color = "cyan",
      }
    end
    for i = 1, #snapshot.gases do
      local it = snapshot.gases[i]
      combined_rows[#combined_rows + 1] = {
        name = ellipsize(it.name, compact and 16 or 28),
        qty = comma_num(it.qty),
        qty_num = it.qty,
        color = "orange",
      }
    end
    local sorted_items = sorted_rows_by_mode(combined_rows, s.sort_mode)
    local item_panel_h = clamp(math.floor(screen_h * (compact and 0.42 or 0.48)), 8, 18)
    local item_content_h = math.max(4, item_panel_h - 2) -- account for panel padding
    local item_limit = math.max(3, item_content_h - 4) -- title + hint + legend + optional hidden line
    local shown_items = {}
    for i = 1, math.min(#sorted_items, item_limit) do
      shown_items[#shown_items + 1] = sorted_items[i]
    end
    local hidden_items = math.max(0, #sorted_items - #shown_items)
    local used_lines = 1 + #shown_items + (hidden_items > 0 and 1 or 0) + 1 + 1
    local spacer_count = math.max(0, item_content_h - used_lines)
    local spacer_lines = {}
    for i = 1, spacer_count do
      spacer_lines[i] = i
    end

    return {
      _version = s.version,
      storage_name = ellipsize(snapshot.name, compact and (screen_w - 6) or 50),
      storage_idx = s.storage_idx,
      storage_count = #s.storages,
      sort_mode = s.sort_mode,
      compact = compact,
      item_used = comma_num(snapshot.item_used),
      item_capacity = comma_num(snapshot.item_capacity),
      item_pct = item_pct,
      item_bar = item_bar,
      fluid_used = comma_num(snapshot.fluid_used),
      fluid_capacity = comma_num(snapshot.fluid_capacity),
      fluid_pct = fluid_pct,
      fluid_bar = fluid_bar,
      gas_used = comma_num(snapshot.gas_used),
      gas_capacity = comma_num(snapshot.gas_capacity),
      gas_pct = gas_pct,
      gas_bar = gas_bar,
      item_panel_h = item_panel_h,
      items = shown_items,
      hidden_items = hidden_items,
      item_spacer_lines = spacer_lines,
    }
  end,
  contextHash = function(_, s) return s.version end,
  trackImports = true,
  onEvent = function(ev, a, _, _, _, s, rerender)
    if ev ~= "key" then return end
    if a == keys.q then
      error("demo exit (Q)")
    elseif a == keys.right then
      s.storage_idx = (s.storage_idx % #s.storages) + 1
      bump(s)
      rerender()
    elseif a == keys.left then
      s.storage_idx = ((s.storage_idx - 2 + #s.storages) % #s.storages) + 1
      bump(s)
      rerender()
    elseif a == keys.r then
      s.tick = s.tick + 1
      bump(s)
      rerender()
    end
  end,
  onError = function(err)
    print("[v2 demo error] " .. tostring(err))
  end,
})
