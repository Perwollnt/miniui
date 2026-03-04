local hash = require("core.hash")
local lru = require("core.lru")
local tokenizer = require("template.tokenizer")
local parser = require("template.parser")
local evaluator = require("template.evaluator")

local Loader = {}
Loader.__index = Loader

local function is_url(s)
  return type(s) == "string" and s:match("^https?://") ~= nil
end

local function url_dir(url)
  local dir = url:match("^(https?://.*/)")
  if dir then
    return dir
  end
  return url
end

local function read_file(path)
  local h = fs.open(path, "r")
  if not h then
    return nil, "no such file: " .. tostring(path)
  end
  local s = h.readAll()
  h.close()
  return s, nil
end

local function read_url(url)
  if not http or not http.get then
    return nil, "http API unavailable"
  end

  local resp = http.get(url, nil, true)
  if not resp then
    return nil, "http.get failed: " .. tostring(url)
  end

  local body = resp.readAll()
  resp.close()
  return body, nil
end

local function gather_imports_from_nodes(nodes, out)
  for i = 1, #nodes do
    local n = nodes[i]
    if n.type == "Import" then
      out[#out + 1] = n.path
    elseif n.type == "If" then
      for bi = 1, #(n.branches or {}) do
        gather_imports_from_nodes(n.branches[bi].body or {}, out)
      end
      if n.else_body then gather_imports_from_nodes(n.else_body, out) end
    elseif n.type == "For" then
      gather_imports_from_nodes(n.body or {}, out)
    elseif n.type == "Switch" then
      for ci = 1, #(n.cases or {}) do
        gather_imports_from_nodes(n.cases[ci].body or {}, out)
      end
      if n.default_body then gather_imports_from_nodes(n.default_body, out) end
    end
  end
end

function Loader.new(opts)
  opts = opts or {}
  local self = setmetatable({}, Loader)
  self.cache = lru.new(opts.max_entries or 48)
  self.compiler_cache = lru.new(opts.max_compiled or 48)
  self.root = opts.root or "."
  self.max_import_depth = tonumber(opts.max_import_depth) or 24
  return self
end

function Loader:resolve(base, path)
  if is_url(path) then
    return path
  end
  if type(base) == "string" and is_url(base) then
    return url_dir(base) .. path
  end
  return fs.combine(base or self.root, path)
end

function Loader:load(source, opts)
  opts = opts or {}
  local cached = self.cache:get(source)
  if cached and not opts.force_reload then
    return cached.content, cached
  end

  local content, err
  if is_url(source) then
    content, err = read_url(source)
  else
    content, err = read_file(source)
  end
  if not content then
    return nil, err
  end

  local meta = {
    source = source,
    content = content,
    hash = hash.fnv1a32(content),
    loaded_at = os.clock(),
  }
  self.cache:set(source, meta)
  return content, meta
end

function Loader:compile_string(src, cache_key)
  local src_hash = hash.fnv1a32(src)
  cache_key = cache_key or ("inline:" .. src_hash)
  local cached = self.compiler_cache:get(cache_key)
  if cached and cached.source_hash == src_hash then
    return cached
  end

  local tokens = tokenizer.tokenize(src)
  local ok, ast_or_err = pcall(parser.parse, tokens)
  if not ok then
    return nil, tostring(ast_or_err)
  end
  local ast = ast_or_err
  local compiled = { ast = ast, source_hash = src_hash }
  self.compiler_cache:set(cache_key, compiled)
  return compiled
end

function Loader:compile_source(source, opts)
  local content, meta_or_err = self:load(source, opts)
  if not content then
    return nil, meta_or_err
  end
  local compiled, err = self:compile_string(content, source)
  if not compiled then
    return nil, err
  end
  compiled.source = source
  compiled.source_hash = meta_or_err.hash
  return compiled
end

function Loader:render_import(path, ctx, opts, state)
  opts = opts or {}
  local base = opts.base or self.root
  local resolved = self:resolve(base, path)
  local depth = (opts.import_depth or 0) + 1
  if depth > self.max_import_depth then
    return "[import error: max depth exceeded]"
  end

  local guard = opts.import_guard or {}
  if guard[resolved] then
    return "[import error: cycle detected: " .. tostring(resolved) .. "]"
  end
  guard[resolved] = true

  local compiled, err = self:compile_source(resolved)
  if not compiled then
    guard[resolved] = nil
    return "[import error: " .. tostring(err) .. "]"
  end

  local next_opts = {
    loader = self,
    base = is_url(resolved) and url_dir(resolved) or fs.getDir(resolved),
    strict_control = opts.strict_control,
    import_depth = depth,
    import_guard = guard,
  }
  local rendered = evaluator.evaluate(compiled.ast, ctx, next_opts, state)
  guard[resolved] = nil
  return rendered
end

function Loader:fingerprint(source, opts)
  opts = opts or {}
  local visited = opts.visited or {}
  if visited[source] then
    return "cycle:" .. tostring(source), nil
  end
  visited[source] = true

  local compiled, err = self:compile_source(source, { force_reload = opts.force_reload })
  if not compiled then
    visited[source] = nil
    return nil, err
  end

  local imports = {}
  gather_imports_from_nodes(compiled.ast.body or {}, imports)

  local base = opts.base or (is_url(source) and url_dir(source) or fs.getDir(source))
  local parts = { compiled.source_hash }
  for i = 1, #imports do
    local resolved = self:resolve(base, imports[i])
    local sub_hash, ferr = self:fingerprint(resolved, {
      force_reload = opts.force_reload,
      visited = visited,
      base = is_url(resolved) and url_dir(resolved) or fs.getDir(resolved),
    })
    if not sub_hash then
      parts[#parts + 1] = "error:" .. tostring(ferr)
    else
      parts[#parts + 1] = sub_hash
    end
  end

  visited[source] = nil
  return hash.fnv1a32(table.concat(parts, "|")), nil
end

return Loader

