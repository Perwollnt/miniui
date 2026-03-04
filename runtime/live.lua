local hash = require("core.hash")

local M = {}

-- Poll-based live loop intended for CC memory/CPU limits.
function M.run(cfg)
  local source = assert(cfg.source, "runLive requires config.source")
  local render_once = assert(cfg.render_once, "runLive requires config.render_once")
  local interval = tonumber(cfg.pollInterval) or 0.5
  local context_provider = cfg.contextProvider
  local state = cfg.state or {}

  local last_source_hash = nil
  local last_ctx_hash = nil
  local last_frame = nil
  local dirty = false
  local timer = os.startTimer(interval)

  local function request_rerender()
    if not dirty then
      dirty = true
      os.queueEvent("ui_v2_rerender")
    end
  end

  local function current_ctx()
    if type(context_provider) == "function" then
      return context_provider(state) or {}
    end
    return {}
  end

  local function calc_ctx_hash(ctx)
    if type(cfg.contextHash) == "function" then
      return tostring(cfg.contextHash(ctx, state))
    end
    if type(ctx) ~= "table" then
      return tostring(ctx)
    end
    if ctx._hash ~= nil then
      return tostring(ctx._hash)
    end
    if ctx._version ~= nil then
      return tostring(ctx._version)
    end
    if cfg.allowSerializeHash then
      return hash.fnv1a32(textutils.serialize(ctx))
    end
    return "static"
  end

  local function do_render(ctx)
    last_frame = render_once(source, ctx, state)
    return last_frame
  end

  -- Initial paint so event handlers can work immediately.
  local init_ctx = current_ctx()
  do_render(init_ctx)
  last_ctx_hash = calc_ctx_hash(init_ctx)
  last_source_hash = cfg.source_hash_fn(source)

  while true do
    local ev, a, b, c = os.pullEvent()
    if ev == "timer" and a == timer then
      local ctx = current_ctx()
      local ctx_hash = calc_ctx_hash(ctx)
      local src_hash = cfg.source_hash_fn(source)
      if src_hash ~= last_source_hash or ctx_hash ~= last_ctx_hash then
        do_render(ctx)
        last_source_hash = src_hash
        last_ctx_hash = ctx_hash
      end
      timer = os.startTimer(interval)
    elseif ev == "ui_v2_rerender" then
      if dirty then
        do_render(current_ctx())
        dirty = false
      end
    elseif ev == "term_resize" then
      local ctx = current_ctx()
      do_render(ctx)
    elseif cfg.onEvent then
      cfg.onEvent(ev, a, b, c, last_frame, state, request_rerender)
    end
  end
end

return M

