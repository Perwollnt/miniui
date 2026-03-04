# miniui v2 (standalone)

## Status
- Standalone from v1 runtime modules.
- Supports:
  - `{{ expr }}`
  - `{{ if ... }} ... {{ elseif ... }} ... {{ else }} ... {{ end }}`
  - `{{ for item in items }} ... {{ end }}`
  - `{{ for i, item in items }} ... {{ end }}`
  - `{{ switch value }} {{ case "x" }} ... {{ default }} ... {{ end }}`
  - `{{ import "partial.ui" }}`
  - URL imports if CC HTTP API is enabled.

## API
- `UI.compile(template_or_source, { is_source? })`
- `UI.render(template_or_compiled, ctx, { target?, base? })`
- `UI.renderFile(path, ctx, { target? })`
- `UI.renderURL(url, ctx, { target? })`
- `UI.runLive({ source, target?, state?, handlers?, pollInterval?, contextProvider?, contextHash?, allowSerializeHash?, trackImports? })`

## Live performance
- Best practice: provide a cheap `contextHash`:
  - `contextHash = function(ctx, state) return state.version end`
- Or set `ctx._version` in your `contextProvider`.
- Avoid `allowSerializeHash = true` unless needed (more CPU/memory).
- `trackImports` defaults to `true` (live reload also watches imported partials).

## Example
```lua
local UI = require("ui")

local state = { version = 0, items = { "A", "B" } }

UI.runLive({
  source = "screen.ui",
  target = "monitor_1",
  state = state,
  pollInterval = 0.5,
  contextProvider = function(s)
    return {
      _version = s.version,
      items = s.items,
      mode = s.mode or "ok",
    }
  end,
  handlers = {
    add = function(_, s, rerender)
      s.items[#s.items + 1] = "N" .. tostring(#s.items + 1)
      s.version = s.version + 1
      rerender()
    end
  }
})
```

## Demo
- Run live demo:
  - `lua demo_live.lua` (local terminal)
  - `lua demo_live.lua monitor_1` (monitor)
- Edit these files while demo is running:
  - `examples/live/page.ui`
  - `examples/live/partials/item.ui`

## HTTP Demo
- Start server from host machine:
  - `powershell -ExecutionPolicy Bypass -File .\httpdemo\start.ps1 -Port 8080`
  - or `python httpdemo/server.py --port 8080`
- Run on CC:
  - `demo_http http://<YOUR_PC_IP>:8080/page.ui`
- Remote imports are resolved relative to the same base URL.

## Benchmark
- Template-only benchmark (compile+evaluate template AST):
- `lua benchmark.lua template examples/live/page.ui 200`
- Full benchmark (template + markup parse + layout + render):
- `lua benchmark.lua full examples/live/page.ui 100`
- Optional target in full mode:
- `lua benchmark.lua full examples/live/page.ui 100 monitor_1`
