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

local source = fs.combine(miniui_root, "examples/live/page.ui")
local target = ...

local state = {
  version = 1,
  count = 0,
  online = true,
  mode_idx = 1,
  modes = { "ok", "warn", "error" },
  items = {
    { name = "Iron", qty = 12 },
    { name = "Gold", qty = 4 },
    { name = "Coal", qty = 31 },
  },
}

local function current_mode(s)
  return s.modes[s.mode_idx] or "ok"
end

local function bump(s)
  s.version = s.version + 1
end

local handlers = {
  inc = function(_, s, rerender)
    s.count = s.count + 1
    bump(s)
    rerender()
  end,
  dec = function(_, s, rerender)
    s.count = s.count - 1
    bump(s)
    rerender()
  end,
  toggle = function(_, s, rerender)
    s.online = not s.online
    s.mode_idx = (s.mode_idx % #s.modes) + 1
    bump(s)
    rerender()
  end,
}

print("miniui live demo")
print("Source:", source)
print("Edit the source/partials in VS Code and save to live reload.")

V2.runLive({
  source = source,
  target = target,
  state = state,
  handlers = handlers,
  pollInterval = 0.25,
  contextProvider = function(s)
    return {
      _version = s.version,
      count = s.count,
      online = s.online,
      mode = current_mode(s),
      items = s.items,
    }
  end,
  contextHash = function(_, s) return s.version end,
  trackImports = true,
  onEvent = function(ev, a, _, _, _, s, rerender)
    if ev ~= "key" then return end
    if a == keys.q then
      error("demo exit (Q)")
    elseif a == keys.a then
      s.items[#s.items + 1] = { name = "Item" .. tostring(#s.items + 1), qty = math.random(1, 64) }
      bump(s)
      rerender()
    elseif a == keys.m then
      s.mode_idx = (s.mode_idx % #s.modes) + 1
      bump(s)
      rerender()
    elseif a == keys.o then
      s.online = not s.online
      bump(s)
      rerender()
    end
  end,
  onError = function(err)
    print("[v2 demo error] " .. tostring(err))
  end,
})
