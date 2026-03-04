--[[
miniui entrypoint (V2-only)

Use this file as the public API:
  local UI = require("ui")

Primary APIs:
  UI.compile(template_or_source, opts?)
  UI.render(template_or_compiled, ctx?, opts?)
  UI.renderFile(path, ctx?, opts?)
  UI.renderURL(url, ctx?, opts?)
  UI.runLive(config)
  UI.benchmark(opts?)
  UI.printBenchmark(result)

Compatibility:
  UI.v2 points to the same table for older scripts expecting UI.v2.*
]]

local function load_local(rel)
  local roots = {
    rawget(_G, "__MINIUI_ROOT"),
    "/miniui",
    "miniui",
    ".",
  }
  if shell and shell.dir then
    local d = shell.dir()
    roots[#roots + 1] = d
    roots[#roots + 1] = fs.combine(d, "miniui")
    roots[#roots + 1] = fs.combine(d, "..")
  end
  for i = 1, #roots do
    local r = roots[i]
    if r and r ~= "" then
      local p = fs.combine(r, rel)
      if fs.exists(p) then
        return dofile(p)
      end
    end
  end
  error("miniui missing file: " .. tostring(rel))
end

local Engine = load_local("ui_engine.lua")
local Bench = nil

local UI = {}

-- Forward all engine APIs.
for k, v in pairs(Engine) do
  UI[k] = v
end

function UI.benchmark(opts)
  if not Bench then
    Bench = load_local("benchmark.lua")
  end
  return Bench.run(opts or {})
end

function UI.printBenchmark(result)
  if not result then
    print("[benchmark] no result")
    return
  end
  print("mode:", result.mode)
  print("iterations:", result.iterations)
  print(("total: %.4fs"):format(result.total_s or 0))
  print(("avg: %.3fms/render"):format(result.avg_ms or 0))
  print(("mem: %.2fKB -> %.2fKB (delta %.2fKB)"):format(
    result.mem_before_kb or 0,
    result.mem_after_kb or 0,
    result.mem_delta_kb or 0
  ))
end

-- Legacy bridge: old callers use UI.v2.*
UI.v2 = UI

return UI
