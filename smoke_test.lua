-- miniui smoke test for CraftOS / CC:Tweaked
-- Run: smoke_test

local root = "/miniui"
if not fs.exists(root) then
  root = "miniui"
end
if not fs.exists(root) then
  root = "."
end

_G.__MINIUI_ROOT = root

local ui_path = fs.combine(root, "ui.lua")
if not fs.exists(ui_path) then
  error("ui.lua not found at " .. tostring(ui_path))
end

local UI = dofile(ui_path)
if type(UI) ~= "table" then
  error("ui.lua did not return a table")
end
if type(UI.v2) ~= "table" then
  error("UI.v2 missing")
end

-- Basic compile/evaluate path.
local tpl = [[
<col><text>{{ if online }}ok{{ else }}off{{ end }}</text></col>
]]
local compiled, err = UI.compile(tpl)
if not compiled then
  error("compile failed: " .. tostring(err))
end

-- Render to current terminal.
local frame = UI.render(compiled, { online = true }, {})
if type(frame) ~= "table" or type(frame.root) ~= "table" then
  error("render failed")
end

print("miniui smoke test OK")
