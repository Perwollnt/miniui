# httpdemo

Remote template demo for miniui.

This folder hosts a static template set that `demo_http.lua` pulls over HTTP.

## Run server

PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File .\httpdemo\start.ps1 -Port 8080
```

Python:

```bash
python httpdemo/server.py --port 8080
```

## Run on CC

```lua
miniui/demo_http http://<YOUR_PC_IP>:8080/page.ui
```

`page.ui` imports:
- `partials/header.ui`
- `partials/item.ui`

Imports resolve relative to the same URL base.
