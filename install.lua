-- miniui installer for CC:Tweaked
--
-- Usage:
--   install.lua
--   install.lua http://localhost:1234/uikit
--   install.lua -s http://localhost:1234/uikit
--   install.lua -s http://localhost:1234/uikit -d miniui
--   install.lua -s http://localhost:1234/uikit -d miniui --force

local DEFAULT_SOURCE = "http://localhost:1234/uikit"
local DEFAULT_TARGET_DIR = "miniui"
local MANIFEST_FILE = "install_manifest.txt"
local DEFAULT_RETRIES = 2

local function println(...)
  print(...)
end

local function usage()
  println("miniui installer")
  println("Usage:")
  println("  install.lua [source_url]")
  println("  install.lua -s <source_url> [-d <target_dir>] [--force]")
  println("")
  println("Options:")
  println("  -s, --source   Source base URL (default: " .. DEFAULT_SOURCE .. ")")
  println("  -d, --dir      Install directory (default: " .. DEFAULT_TARGET_DIR .. ")")
  println("  -r, --retries  Retry count per file (default: " .. DEFAULT_RETRIES .. ")")
  println("  -f, --force    Delete existing target dir before install")
  println("  -h, --help     Show this help")
  println("")
  println("Example:")
  println("  install.lua -s http://localhost:1234/uikit -d miniui")
end

local function parse_args(args)
  local cfg = {
    source = nil,
    target_dir = DEFAULT_TARGET_DIR,
    retries = DEFAULT_RETRIES,
    force = false,
    help = false,
  }

  local i = 1
  while i <= #args do
    local a = args[i]
    if a == "-h" or a == "--help" then
      cfg.help = true
      i = i + 1
    elseif a == "-f" or a == "--force" then
      cfg.force = true
      i = i + 1
    elseif a == "-s" or a == "--source" then
      if i + 1 > #args then
        return nil, "missing value for " .. a
      end
      cfg.source = args[i + 1]
      i = i + 2
    elseif a == "-d" or a == "--dir" then
      if i + 1 > #args then
        return nil, "missing value for " .. a
      end
      cfg.target_dir = args[i + 1]
      i = i + 2
    elseif a == "-r" or a == "--retries" then
      if i + 1 > #args then
        return nil, "missing value for " .. a
      end
      cfg.retries = tonumber(args[i + 1]) or DEFAULT_RETRIES
      if cfg.retries < 0 then cfg.retries = 0 end
      i = i + 2
    elseif a:sub(1, 1) == "-" then
      return nil, "unknown option: " .. a
    else
      if cfg.source ~= nil then
        return nil, "source provided more than once"
      end
      cfg.source = a
      i = i + 1
    end
  end

  if not cfg.source or cfg.source == "" then
    cfg.source = DEFAULT_SOURCE
  end
  cfg.source = cfg.source:gsub("/+$", "")
  return cfg
end

local function encode_path(path)
  -- Keep slashes so path structure remains valid.
  return (path:gsub("([^%w%-%._~/])", function(ch)
    return string.format("%%%02X", string.byte(ch))
  end))
end

local function http_get_text(url)
  if not http or not http.get then
    return nil, "http API unavailable (enable HTTP in CC:Tweaked config)"
  end

  local resp, err = http.get(url, nil, true)
  if not resp then
    return nil, err or ("request failed: " .. tostring(url))
  end

  local code = resp.getResponseCode and resp.getResponseCode() or 200
  local body = resp.readAll()
  resp.close()
  if code ~= 200 then
    return nil, ("HTTP %s for %s"):format(tostring(code), url)
  end
  return body
end

local function http_get_text_retry(url, retries)
  local last = nil
  for i = 0, retries do
    local body, err = http_get_text(url)
    if body then return body, nil end
    last = err
    if i < retries then sleep(0.05) end
  end
  return nil, last
end

local function ensure_parent(path)
  local dir = fs.getDir(path)
  if dir and dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local function split_lines(s)
  local out = {}
  for line in (s .. "\n"):gmatch("(.-)\n") do
    out[#out + 1] = line
  end
  return out
end

local function parse_manifest(text)
  local files = {}
  for _, raw in ipairs(split_lines(text)) do
    local line = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and line:sub(1, 1) ~= "#" then
      files[#files + 1] = line
    end
  end
  return files
end

local function write_file(path, content)
  ensure_parent(path)
  local h = fs.open(path, "w")
  if not h then
    return nil, "failed to open for write: " .. path
  end
  h.write(content)
  h.close()
  return true
end

local function install(cfg)
  local manifest_url = cfg.source .. "/" .. MANIFEST_FILE
  println("Source: " .. cfg.source)
  println("Target: " .. cfg.target_dir)
  println("Retries: " .. tostring(cfg.retries))
  println("Fetching manifest: " .. manifest_url)

  local manifest_text, merr = http_get_text_retry(manifest_url, cfg.retries)
  if not manifest_text then
    return nil, "manifest download failed: " .. tostring(merr)
  end

  local files = parse_manifest(manifest_text)
  if #files == 0 then
    return nil, "manifest is empty"
  end

  local stage_dir = cfg.target_dir .. ".__installing"
  if fs.exists(stage_dir) then fs.delete(stage_dir) end
  fs.makeDir(stage_dir)

  local ok_count = 0
  for i = 1, #files do
    local rel = files[i]
    local url = cfg.source .. "/" .. encode_path(rel)
    local dest = fs.combine(stage_dir, rel)
    println(("[%d/%d] %s"):format(i, #files, rel))

    local body, ferr = http_get_text_retry(url, cfg.retries)
    if not body then
      return nil, ("download failed for %s: %s"):format(rel, tostring(ferr))
    end

    local ok, werr = write_file(dest, body)
    if not ok then
      return nil, ("write failed for %s: %s"):format(dest, tostring(werr))
    end
    ok_count = ok_count + 1
  end

  local backup_dir = cfg.target_dir .. ".__backup"
  if fs.exists(backup_dir) then fs.delete(backup_dir) end
  if fs.exists(cfg.target_dir) then
    if not cfg.force then
      -- keep current install as backup and replace atomically
      fs.move(cfg.target_dir, backup_dir)
    else
      fs.delete(cfg.target_dir)
    end
  end
  fs.move(stage_dir, cfg.target_dir)
  if fs.exists(backup_dir) then fs.delete(backup_dir) end

  return {
    files = ok_count,
    dir = cfg.target_dir,
    source = cfg.source,
  }
end

local args = { ... }
local cfg, perr = parse_args(args)
if not cfg then
  println("Argument error: " .. tostring(perr))
  usage()
  return
end

if cfg.help then
  usage()
  return
end

local result, err = install(cfg)
if not result then
  println("Install failed: " .. tostring(err))
  return
end

println("")
println(("Installed %d files to %s"):format(result.files, result.dir))
println("In your program use:")
println('  local UI = require("ui")')
