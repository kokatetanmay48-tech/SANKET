# SANKET Local Static Web Server
param(
    [int]$Port = 8080,
    [switch]$OpenBrowser
)

$root = $PSScriptRoot
if (-not $root) { $root = Get-Location }

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".webmanifest" = "application/manifest+json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".map"  = "application/json"
}

# Find an available port if requested port is in use
$testPort = $Port
$maxAttempts = 10
$listener = $null

for ($i = 0; $i -lt $maxAttempts; $i++) {
    try {
        $tempListener = New-Object System.Net.HttpListener
        $prefix = "http://localhost:$testPort/"
        $tempListener.Prefixes.Add($prefix)
        $tempListener.Start()
        $listener = $tempListener
        $Port = $testPort
        break
    } catch {
        $testPort++
    }
}

if (-not $listener) {
    Write-Error "Failed to bind to any port starting from $Port"
    exit 1
}

$url = "http://localhost:$Port/"
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  SANKET C2 Command - Local Web Server   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Server running at: $url" -ForegroundColor Yellow
Write-Host "Serving files from: $root" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop the server." -ForegroundColor Gray
Write-Host "=========================================" -ForegroundColor Green

if ($OpenBrowser) {
    Start-Process $url
}

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $rawPath = [System.Uri]::UnescapeDataString($request.Url.LocalPath)
        if ($rawPath -eq "/" -or [string]::IsNullOrWhiteSpace($rawPath)) {
            $rawPath = "/index.html"
        }

        # Normalize relative path
        $relPath = $rawPath.TrimStart('/').Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $fullPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($root, $relPath))

        # Security check: prevent directory traversal outside root
        if (-not $fullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            $response.StatusCode = 403
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("403 Forbidden")
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
            $response.OutputStream.Close()
            continue
        }

        if (Test-Path -Path $fullPath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($fullPath).ToLower()
            $contentType = if ($mimeTypes.ContainsKey($ext)) { $mimeTypes[$ext] } else { "application/octet-stream" }
            
            try {
                $fileBytes = [System.IO.File]::ReadAllBytes($fullPath)
                $response.ContentType = $contentType
                $response.ContentLength64 = $fileBytes.Length
                $response.StatusCode = 200
                $response.AddHeader("Cache-Control", "no-cache")
                $response.OutputStream.Write($fileBytes, 0, $fileBytes.Length)
            } catch {
                $response.StatusCode = 500
            }
        } else {
            $response.StatusCode = 404
            $bytes = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $rawPath")
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        }

        $response.OutputStream.Close()
    }
} finally {
    if ($listener) {
        $listener.Stop()
        $listener.Close()
    }
}
