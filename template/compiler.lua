local Loader = require("template.loader")
local evaluator = require("template.evaluator")

local M = {}

function M.new(opts)
  local loader = Loader.new(opts)
  local api = { loader = loader }

  function api:compile(template_or_source, opts2)
    opts2 = opts2 or {}
    if opts2.is_source then
      return self.loader:compile_source(template_or_source, opts2)
    end
    return self.loader:compile_string(template_or_source, opts2.cache_key)
  end

  function api:render(compiled, ctx, opts2)
    opts2 = opts2 or {}
    local eval_opts = {
      loader = self.loader,
      base = opts2.base or self.loader.root,
      strict_control = opts2.strict_control,
    }
    return evaluator.evaluate(compiled.ast, ctx or {}, eval_opts)
  end

  return api
end

return M

