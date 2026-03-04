local function has_segment(path, seg)
  return type(path) == "string" and path:find(seg, 1, true) ~= nil
end

local function add_package_pattern(pattern)
  if not package or type(package.path) ~= "string" then return end
  if not has_segment(package.path, pattern) then
    package.path = package.path .. ";" .. pattern
  end
end

local function ensure_module_paths()
  -- Relative to caller cwd.
  add_package_pattern("./?.lua")
  add_package_pattern("./?/init.lua")
  add_package_pattern("./?/?/?.lua")

  -- If called from nested folders, parent may hold the kit root.
  add_package_pattern("../?.lua")
  add_package_pattern("../?/init.lua")
  add_package_pattern("../?/?/?.lua")

  -- Common install locations.
  add_package_pattern("miniui/?.lua")
  add_package_pattern("miniui/?/init.lua")
  add_package_pattern("miniui/?/?.lua")
  add_package_pattern("/miniui/?.lua")
  add_package_pattern("/miniui/?/init.lua")
  add_package_pattern("/miniui/?/?.lua")
end

ensure_module_paths()

local function candidate_roots()
  local roots = {}
  local function add(r)
    if not r or r == "" then return end
    for i = 1, #roots do
      if roots[i] == r then return end
    end
    roots[#roots + 1] = r
  end

  add(rawget(_G, "__MINIUI_ROOT"))
  add(".")
  add("..")
  add("/miniui")
  add("miniui")
  if shell and shell.dir then
    local d = shell.dir()
    add(d)
    add(fs.combine(d, ".."))
    add(fs.combine(d, "miniui"))
  end
  return roots
end

local function resolve_module_path(name)
  local rel = name:gsub("%.", "/") .. ".lua"
  local roots = candidate_roots()
  for i = 1, #roots do
    local p = fs.combine(roots[i], rel)
    if fs.exists(p) then
      return p
    end
  end
  return nil
end

if type(require) ~= "function" then
  local loaded = rawget(_G, "__MINIUI_LOADED")
  if type(loaded) ~= "table" then
    loaded = {}
    rawset(_G, "__MINIUI_LOADED", loaded)
  end

  _G.require = function(name)
    if loaded[name] ~= nil then
      return loaded[name]
    end
    local p = resolve_module_path(name)
    if not p then
      error("module '" .. tostring(name) .. "' not found (miniui require shim)")
    end
    local mod = dofile(p)
    if mod == nil then mod = true end
    loaded[name] = mod
    return mod
  end
end

local function load_module(name, fallback_rel)
  if type(require) == "function" then
    local ok, mod = pcall(require, name)
    if ok then return mod end
  end

  local roots = candidate_roots()
  for i = 1, #roots do
    local path = fs.combine(roots[i], fallback_rel)
    if fs.exists(path) then
      return dofile(path)
    end
  end
  error("module not found: " .. tostring(name) .. " (fallback: " .. tostring(fallback_rel) .. ")")
end

local compiler_factory = load_module("template.compiler", "template/compiler.lua")
local live = load_module("runtime.live", "runtime/live.lua")
local markup = load_module("markup.parser", "markup/parser.lua")
local reconcile = load_module("vdom.reconcile", "vdom/reconcile.lua")
local dispatch = load_module("events.dispatch", "events/dispatch.lua")
local Node = load_module("vdom.node", "vdom/node.lua")
local htmlshim = load_module("html.shim", "html/shim.lua")

local M = {}

local engine = compiler_factory.new({
  root = ".",
  max_entries = 32,
  max_compiled = 32,
})

local function is_url(s)
  return type(s) == "string" and s:match("^https?://") ~= nil
end

local function source_dir(s)
  if is_url(s) then
    return s:match("^(https?://.*/)") or s
  end
  return fs.getDir(s)
end

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

local function monitor_matches_target(target, side)
  if type(target) == "string" then
    return side == target
  end
  if type(target) == "table" and peripheral and peripheral.getName then
    local ok, name = pcall(peripheral.getName, target)
    if ok and name then
      return side == name
    end
  end
  return true
end

function M.new(opts)
  opts = opts or {}
  local e = engine
  if opts.root or opts.max_entries or opts.max_compiled then
    e = compiler_factory.new(opts)
  end

  local inst = {}

  function inst.compile(template_or_source, compile_opts)
    return e:compile(template_or_source, compile_opts or {})
  end

  function inst.attach(any)
    return reconcile.attach(any)
  end

  function inst.h(tag, props, children)
    return Node.new(tag, props or {}, children or {})
  end

  function inst.htmlToMini(html)
    return htmlshim.htmlToMini(html)
  end

  function inst.render(template_or_compiled, ctx, render_opts)
    render_opts = render_opts or {}
    local compiled = template_or_compiled
    if type(template_or_compiled) == "string" then
      local err
      compiled, err = e:compile(template_or_compiled, { cache_key = render_opts.cache_key })
      if not compiled then
        error("render compile failed: " .. tostring(err))
      end
    end
    local markup_str = e:render(compiled, ctx, render_opts)
    return render_markup(markup_str, render_opts.target)
  end

  function inst.renderFile(path, ctx, render_opts)
    render_opts = render_opts or {}
    local compiled, err = e:compile(path, { is_source = true })
    if not compiled then
      error("renderFile compile failed: " .. tostring(err))
    end
    render_opts.base = source_dir(path)
    return inst.render(compiled, ctx, render_opts)
  end

  function inst.renderURL(url, ctx, render_opts)
    render_opts = render_opts or {}
    local compiled, err = e:compile(url, { is_source = true })
    if not compiled then
      error("renderURL compile failed: " .. tostring(err))
    end
    render_opts.base = source_dir(url)
    return inst.render(compiled, ctx, render_opts)
  end

  function inst.runLive(cfg)
    local source = assert(cfg.source, "runLive requires source")
    local target = cfg.target
    local state = cfg.state or {}
    local handlers = cfg.handlers or {}

    local function source_hash_fn(src)
      if cfg.trackImports ~= false then
        local fp, ferr = e.loader:fingerprint(src, { force_reload = true, base = source_dir(src) })
        if not fp then
          return "error:" .. tostring(ferr)
        end
        return fp
      end
      local content, meta_or_err = e.loader:load(src, { force_reload = true })
      if not content then
        return "error:" .. tostring(meta_or_err)
      end
      return meta_or_err.hash
    end

    local function render_once(src, ctx, st)
      local compiled, err = e:compile(src, { is_source = true, force_reload = true })
      if not compiled then
        if cfg.onError then cfg.onError(err, st) end
        return nil
      end
      local markup_str = e:render(compiled, ctx, { base = source_dir(src), strict_control = cfg.strict_control })
      local frame = render_markup(markup_str, target)
      if cfg.afterRender then cfg.afterRender(st, frame) end
      return frame
    end

    return live.run({
      source = source,
      state = state,
      pollInterval = cfg.pollInterval or 0.5,
      contextProvider = cfg.contextProvider,
      contextHash = cfg.contextHash,
      allowSerializeHash = cfg.allowSerializeHash,
      source_hash_fn = source_hash_fn,
      render_once = render_once,
      onEvent = function(ev, a, b, c, last_frame, st, request_rerender)
        local hits = last_frame and last_frame.hits
        if ev == "monitor_touch" then
          if hits and monitor_matches_target(target, a) then
            dispatch.dispatch(b, c, hits, handlers, st, request_rerender)
          end
        elseif ev == "mouse_click" then
          if hits then
            dispatch.dispatch(b, c, hits, handlers, st, request_rerender)
          end
        elseif cfg.onEvent then
          cfg.onEvent(ev, a, b, c, last_frame, st, request_rerender)
        end
      end,
    })
  end

  return inst
end

function M.compile(template_or_source, opts)
  opts = opts or {}
  return engine:compile(template_or_source, opts)
end

function M.attach(any)
  return reconcile.attach(any)
end

function M.h(tag, props, children)
  return Node.new(tag, props or {}, children or {})
end

function M.htmlToMini(html)
  return htmlshim.htmlToMini(html)
end

function M.render(template_or_compiled, ctx, opts)
  opts = opts or {}
  local compiled = template_or_compiled
  if type(template_or_compiled) == "string" then
    local err
    compiled, err = engine:compile(template_or_compiled, { cache_key = opts.cache_key })
    if not compiled then
      error("render compile failed: " .. tostring(err))
    end
  end
  local markup_str = engine:render(compiled, ctx, opts)
  return render_markup(markup_str, opts.target)
end

function M.renderFile(path, ctx, opts)
  opts = opts or {}
  local compiled, err = engine:compile(path, { is_source = true })
  if not compiled then
    error("renderFile compile failed: " .. tostring(err))
  end
  opts.base = source_dir(path)
  return M.render(compiled, ctx, opts)
end

function M.renderURL(url, ctx, opts)
  opts = opts or {}
  local compiled, err = engine:compile(url, { is_source = true })
  if not compiled then
    error("renderURL compile failed: " .. tostring(err))
  end
  opts.base = source_dir(url)
  return M.render(compiled, ctx, opts)
end

function M.runLive(cfg)
  local source = assert(cfg.source, "runLive requires source")
  local target = cfg.target
  local state = cfg.state or {}
  local handlers = cfg.handlers or {}

  local function source_hash_fn(src)
    if cfg.trackImports ~= false then
      local fp, ferr = engine.loader:fingerprint(src, { force_reload = true, base = source_dir(src) })
      if not fp then
        return "error:" .. tostring(ferr)
      end
      return fp
    end
    local content, meta_or_err = engine.loader:load(src, { force_reload = true })
    if not content then
      return "error:" .. tostring(meta_or_err)
    end
    return meta_or_err.hash
  end

  local function render_once(src, ctx, st)
    local compiled, err = engine:compile(src, { is_source = true, force_reload = true })
    if not compiled then
      if cfg.onError then cfg.onError(err, st) end
      return nil
    end
    local markup_str = engine:render(compiled, ctx, { base = source_dir(src), strict_control = cfg.strict_control })
    local frame = render_markup(markup_str, target)
    if cfg.afterRender then cfg.afterRender(st, frame) end
    return frame
  end

  return live.run({
    source = source,
    state = state,
    pollInterval = cfg.pollInterval or 0.5,
    contextProvider = cfg.contextProvider,
    contextHash = cfg.contextHash,
    allowSerializeHash = cfg.allowSerializeHash,
    source_hash_fn = source_hash_fn,
    render_once = render_once,
    onEvent = function(ev, a, b, c, last_frame, st, request_rerender)
      local hits = last_frame and last_frame.hits
      if ev == "monitor_touch" then
        if hits and monitor_matches_target(target, a) then
          dispatch.dispatch(b, c, hits, handlers, st, request_rerender)
        end
      elseif ev == "mouse_click" then
        if hits then
          dispatch.dispatch(b, c, hits, handlers, st, request_rerender)
        end
      elseif cfg.onEvent then
        cfg.onEvent(ev, a, b, c, last_frame, st, request_rerender)
      end
    end,
  })
end

return M

