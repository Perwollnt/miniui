param(
    [int]$Port = 1234,
    [string]$Root = ".",
    [string]$Route = "/uikit/"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $Route.StartsWith("/")) { $Route = "/" + $Route }
if (-not $Route.EndsWith("/")) { $Route = $Route + "/" }

$resolvedRoot = (Resolve-Path $Root).Path
$prefix = "http://localhost:$Port/"

Write-Host "miniui dev server"
Write-Host "Root:  $resolvedRoot"
Write-Host "Route: $Route"
Write-Host "URL:   http://localhost:$Port$($Route.TrimStart('/'))"
Write-Host "Press Ctrl+C to stop."

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()

function Get-ContentType([string]$Path) {
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        ".lua"  { "text/plain; charset=utf-8"; break }
        ".md"   { "text/markdown; charset=utf-8"; break }
        ".txt"  { "text/plain; charset=utf-8"; break }
        ".ui"   { "text/plain; charset=utf-8"; break }
        ".json" { "application/json; charset=utf-8"; break }
        ".html" { "text/html; charset=utf-8"; break }
        default { "application/octet-stream" }
    }
}

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response

        try {
            if ($req.HttpMethod -ne "GET") {
                $res.StatusCode = 405
                $res.Close()
                continue
            }

            $path = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath)
            if ($path.Equals("/installer", [System.StringComparison]::OrdinalIgnoreCase) -or
                $path.Equals("/installer.lua", [System.StringComparison]::OrdinalIgnoreCase)) {
                $full = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot "install.lua"))
                if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                    $res.StatusCode = 404
                    $bytes = [System.Text.Encoding]::UTF8.GetBytes("Missing: install.lua`n")
                    $res.ContentType = "text/plain; charset=utf-8"
                    $res.OutputStream.Write($bytes, 0, $bytes.Length)
                    $res.Close()
                    continue
                }

                $bytes = [System.IO.File]::ReadAllBytes($full)
                $res.StatusCode = 200
                $res.ContentType = "text/plain; charset=utf-8"
                $res.ContentLength64 = $bytes.LongLength
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
                Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $path)
                continue
            }

            if (-not $path.StartsWith($Route, [System.StringComparison]::OrdinalIgnoreCase)) {
                $res.StatusCode = 404
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("Not found`n")
                $res.ContentType = "text/plain; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
                continue
            }

            $rel = $path.Substring($Route.Length)
            if ([string]::IsNullOrWhiteSpace($rel)) {
                $rel = "install_manifest.txt"
            }
            $rel = $rel.Replace("/", "\")
            $candidate = Join-Path $resolvedRoot $rel
            $full = [System.IO.Path]::GetFullPath($candidate)

            if (-not $full.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $res.StatusCode = 403
                $res.Close()
                continue
            }

            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                $res.StatusCode = 404
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("Missing: $rel`n")
                $res.ContentType = "text/plain; charset=utf-8"
                $res.OutputStream.Write($bytes, 0, $bytes.Length)
                $res.Close()
                continue
            }

            $bytes = [System.IO.File]::ReadAllBytes($full)
            $res.StatusCode = 200
            $res.ContentType = Get-ContentType $full
            $res.ContentLength64 = $bytes.LongLength
            $res.OutputStream.Write($bytes, 0, $bytes.Length)
            $res.Close()

            Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $path)
        }
        catch {
            try {
                $res.StatusCode = 500
                $msg = [System.Text.Encoding]::UTF8.GetBytes("Server error`n")
                $res.ContentType = "text/plain; charset=utf-8"
                $res.OutputStream.Write($msg, 0, $msg.Length)
                $res.Close()
            }
            catch {}
            Write-Warning $_
        }
    }
}
finally {
    if ($listener.IsListening) {
        $listener.Stop()
    }
    $listener.Close()
}
