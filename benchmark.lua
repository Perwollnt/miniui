local running = (shell and shell.getRunningProgram and shell.getRunningProgram()) or "benchmark.lua"
local here = fs.getDir(running)
if here == "" then here = "." end
local miniui_root = here
if shell and shell.resolve then
  miniui_root = shell.resolve(miniui_root)
end

local ui_path = fs.combine(miniui_root, "ui.lua")
if fs.exists(ui_path) then
  dofile(ui_path)
end

local compiler_factory = require("template.compiler")
local markup = require("markup.parser")
local reconcile = require("vdom.reconcile")
local dispatch = require("events.dispatch")

local M = {}

local function render_markup(markup_or_vdom, target)
  local root
  if type(markup_or_vdom) == "table" and markup_or_vdom.tag then
    root = markup_or_vdom
  else
    root = markup.parse(markup_or_vdom)
  end
  local out = reconcile.render(root, target)
  out.hits = dispatch.collect_clicks(out.root)
  return out
end

local function run_template_only(engine, source, iterations, ctx_fn)
  local compiled, err = engine:compile(source, { is_source = true, force_reload = true })
  if not compiled then
    return nil, "compile failed: " .. tostring(err)
  end

  collectgarbage("collect")
  local mem_before = collectgarbage("count")
  local t0 = os.clock()
  for i = 1, iterations do
    local ctx = ctx_fn(i)
    engine:render(compiled, ctx, { base = fs.getDir(source) })
  end
  local dt = os.clock() - t0
  collectgarbage("collect")
  local mem_after = collectgarbage("count")

  return {
    mode = "template",
    iterations = iterations,
    total_s = dt,
    avg_ms = (dt / iterations) * 1000,
    mem_before_kb = mem_before,
    mem_after_kb = mem_after,
    mem_delta_kb = mem_after - mem_before,
  }
end

local function run_full_render(engine, source, iterations, ctx_fn, target)
  local compiled, err = engine:compile(source, { is_source = true, force_reload = true })
  if not compiled then
    return nil, "compile failed: " .. tostring(err)
  end

  collectgarbage("collect")
  local mem_before = collectgarbage("count")
  local t0 = os.clock()
  for i = 1, iterations do
    local ctx = ctx_fn(i)
    local markup_str = engine:render(compiled, ctx, { base = fs.getDir(source) })
    render_markup(markup_str, target)
  end
  local dt = os.clock() - t0
  collectgarbage("collect")
  local mem_after = collectgarbage("count")

  return {
    mode = "full",
    iterations = iterations,
    total_s = dt,
    avg_ms = (dt / iterations) * 1000,
    mem_before_kb = mem_before,
    mem_after_kb = mem_after,
    mem_delta_kb = mem_after - mem_before,
  }
end

function M.run(opts)
  opts = opts or {}
  local source = opts.source or fs.combine(miniui_root, "examples/live/page.ui")
  local iterations = tonumber(opts.iterations) or 100
  local mode = opts.mode or "template"
  local target = opts.target
  local ctx_fn = opts.contextProvider or function(i)
    return {
      count = i,
      online = (i % 2 == 0),
      mode = (i % 3 == 0 and "error") or (i % 2 == 0 and "warn") or "ok",
      items = {
        { name = "Iron", qty = i },
        { name = "Gold", qty = i * 2 },
        { name = "Coal", qty = i * 3 },
      },
    }
  end

  local engine = compiler_factory.new({
    root = ".",
    max_entries = opts.max_entries or 64,
    max_compiled = opts.max_compiled or 64,
  })

  if mode == "full" then
    return run_full_render(engine, source, iterations, ctx_fn, target)
  end
  return run_template_only(engine, source, iterations, ctx_fn)
end

local function print_result(r)
  print("mode:", r.mode)
  print("iterations:", r.iterations)
  print(("total: %.4fs"):format(r.total_s))
  print(("avg: %.3fms/render"):format(r.avg_ms))
  print(("mem: %.2fKB -> %.2fKB (delta %.2fKB)"):format(r.mem_before_kb, r.mem_after_kb, r.mem_delta_kb))
end

local function run_cli(args)
  local mode = args[1] or "template"
  local source = args[2] or fs.combine(miniui_root, "examples/live/page.ui")
  local iterations = tonumber(args[3]) or 100
  local target = args[4]

  local r, err = M.run({
    mode = mode,
    source = source,
    iterations = iterations,
    target = target,
  })
  if not r then
    print("[benchmark error] " .. tostring(err))
    return
  end
  print_result(r)
end

local args = { ... }
if #args > 0 then
  run_cli(args)
end

return M

