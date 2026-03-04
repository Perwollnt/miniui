param(
    [int]$Port = 8080
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Resolve-Path $PSScriptRoot).Path
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "httpdemo server running at http://localhost:$Port/"
Write-Host "Serving: $root"
Write-Host "Use in CC:"
Write-Host "  demo_http http://<YOUR_PC_IP>:$Port/page.ui"
Write-Host "Press Ctrl+C to stop."

function Get-ContentType([string]$Path) {
    $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    switch ($ext) {
        ".ui"   { "text/plain; charset=utf-8"; break }
        ".lua"  { "text/plain; charset=utf-8"; break }
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
            if ($path -eq "/" -or [string]::IsNullOrWhiteSpace($path)) {
                $path = "/page.ui"
            }
            $rel = $path.TrimStart("/").Replace("/", "\")
            $candidate = Join-Path $root $rel
            $full = [System.IO.Path]::GetFullPath($candidate)

            if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $res.StatusCode = 403
                $res.Close()
                continue
            }

            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                $res.StatusCode = 404
                $bytes = [System.Text.Encoding]::UTF8.GetBytes("Missing: $path`n")
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
            try { $res.StatusCode = 500; $res.Close() } catch {}
            Write-Warning $_
        }
    }
}
finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
}
