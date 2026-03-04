-- HTTP live demo for miniui.
-- Pulls a remote template every N seconds and rerenders on changes.
--
-- Usage:
--   demo_http
--   demo_http http://localhost:8080/page.ui
--   demo_http http://localhost:8080/page.ui monitor_1 0.5

local running = (shell and shell.getRunningProgram and shell.getRunningProgram()) or "demo_http.lua"
local here = fs.getDir(running)
if here == "" then here = "." end
local miniui_root = here
if shell and shell.resolve then
  miniui_root = shell.resolve(miniui_root)
end

_G.__MINIUI_ROOT = miniui_root
local UI = dofile(fs.combine(miniui_root, "ui.lua"))

local args = { ... }
local source = args[1] or "http://localhost:8080/page.ui"
local target = args[2]
local poll = tonumber(args[3]) or 0.5

local state = {
  version = 1,
  count = 0,
  online = true,
  mode_idx = 1,
  modes = { "ok", "warn", "error" },
}

local function mode(s)
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

print("miniui HTTP demo")
print("Source:", source)
print("Poll interval:", poll)

UI.runLive({
  source = source,
  target = target,
  state = state,
  handlers = handlers,
  pollInterval = poll,
  trackImports = true, -- also refresh when imported files change
  contextProvider = function(s)
    return {
      _version = s.version,
      count = s.count,
      online = s.online,
      mode = mode(s),
      items = {
        { name = "Iron", qty = 12 + s.count },
        { name = "Gold", qty = 4 + math.max(0, s.count) },
        { name = "Coal", qty = 31 },
      },
    }
  end,
  contextHash = function(_, s) return s.version end,
  onError = function(err)
    print("[http demo error] " .. tostring(err))
  end,
})
