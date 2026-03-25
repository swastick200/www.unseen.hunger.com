$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$publicDir = Join-Path $root "public"
$dataDir = Join-Path $root "data"
$feedbackFile = Join-Path $dataDir "feedback.json"
$adminToken = if ($env:ADMIN_TOKEN) { $env:ADMIN_TOKEN } else { "unseenhg2056" }

if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir | Out-Null
}

if (-not (Test-Path $feedbackFile)) {
    Set-Content -Path $feedbackFile -Value "[]"
}

function Get-ContentType($path) {
    switch ([System.IO.Path]::GetExtension($path).ToLowerInvariant()) {
        ".html" { "text/html; charset=utf-8" }
        ".css" { "text/css; charset=utf-8" }
        ".js" { "application/javascript; charset=utf-8" }
        ".json" { "application/json; charset=utf-8" }
        ".jpg" { "image/jpeg" }
        ".jpeg" { "image/jpeg" }
        ".png" { "image/png" }
        ".webp" { "image/webp" }
        ".svg" { "image/svg+xml" }
        default { "application/octet-stream" }
    }
}

function Get-ApiHeaders() {
    return @{
        "Access-Control-Allow-Origin" = "*"
        "Access-Control-Allow-Methods" = "GET, POST, OPTIONS"
        "Access-Control-Allow-Headers" = "Content-Type, X-Admin-Token"
    }
}

function Convert-ToJsonText($value) {
    if ($null -eq $value) {
        return "null"
    }

    if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string]) -and -not ($value -is [hashtable]) -and -not ($value -is [pscustomobject])) {
        $items = @($value)
        $jsonItems = foreach ($item in $items) {
            $item | ConvertTo-Json -Depth 8 -Compress
        }

        return "[" + ($jsonItems -join ",") + "]"
    }

    return $value | ConvertTo-Json -Depth 8
}

function Write-Response($stream, $statusCode, $statusText, [byte[]]$body, $contentType, $headers = @{}) {
    $lines = New-Object System.Collections.Generic.List[string]
    [void]$lines.Add("HTTP/1.1 $statusCode $statusText")
    [void]$lines.Add("Content-Type: $contentType")
    [void]$lines.Add("Content-Length: $($body.Length)")
    [void]$lines.Add("Connection: close")

    foreach ($key in $headers.Keys) {
        [void]$lines.Add("${key}: $($headers[$key])")
    }

    [void]$lines.Add("")
    [void]$lines.Add("")

    $headerBytes = [System.Text.Encoding]::UTF8.GetBytes(($lines -join "`r`n"))
    $stream.Write($headerBytes, 0, $headerBytes.Length)

    if ($body.Length -gt 0) {
        $stream.Write($body, 0, $body.Length)
    }
}

function Send-JsonResponse($stream, $statusCode, $statusText, $payload, $headers = @{}) {
    $json = Convert-ToJsonText $payload
    $body = [System.Text.Encoding]::UTF8.GetBytes($json)
    Write-Response $stream $statusCode $statusText $body "application/json; charset=utf-8" $headers
}

function Send-FileResponse($stream, $filePath) {
    if (-not (Test-Path $filePath)) {
        Send-JsonResponse $stream 404 "Not Found" @{ error = "File not found." }
        return
    }

    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    Write-Response $stream 200 "OK" $bytes (Get-ContentType $filePath)
}

function Read-Feedback() {
    if (-not (Test-Path $feedbackFile)) {
        return @()
    }

    $raw = Get-Content -Raw -Path $feedbackFile
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @()
    }

    $parsed = $raw | ConvertFrom-Json
    if ($null -eq $parsed) {
        return @()
    }

    if ($parsed -is [System.Array]) {
        return @($parsed)
    }

    return @($parsed)
}

function Write-Feedback($items) {
    Convert-ToJsonText @($items) | Set-Content -Path $feedbackFile -Encoding UTF8
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 3000)
$listener.Start()

Write-Host "Unseen Hunger local server running on http://localhost:3000"
Write-Host "Press Ctrl+C to stop."

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()

        try {
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::UTF8, $false, 1024, $true)

            $requestLine = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($requestLine)) {
                continue
            }

            $requestParts = $requestLine.Split(" ")
            if ($requestParts.Length -lt 2) {
                Send-JsonResponse $stream 400 "Bad Request" @{ error = "Invalid request line." }
                continue
            }

            $method = $requestParts[0].ToUpperInvariant()
            $target = $requestParts[1]
            $pathOnly = $target.Split("?")[0]
            $path = [System.Uri]::UnescapeDataString($pathOnly.TrimStart("/"))

            $headers = @{}
            while ($true) {
                $line = $reader.ReadLine()
                if ($null -eq $line -or $line -eq "") {
                    break
                }

                $separator = $line.IndexOf(":")
                if ($separator -gt 0) {
                    $name = $line.Substring(0, $separator).Trim().ToLowerInvariant()
                    $value = $line.Substring($separator + 1).Trim()
                    $headers[$name] = $value
                }
            }

            $contentLength = 0
            if ($headers.ContainsKey("content-length")) {
                [void][int]::TryParse($headers["content-length"], [ref]$contentLength)
            }

            $body = ""
            if ($contentLength -gt 0) {
                $buffer = New-Object char[] $contentLength
                $offset = 0
                while ($offset -lt $contentLength) {
                    $read = $reader.Read($buffer, $offset, $contentLength - $offset)
                    if ($read -le 0) {
                        break
                    }
                    $offset += $read
                }
                $body = [string]::new($buffer, 0, $offset)
            }

            if ($method -eq "OPTIONS" -and $path -eq "api/feedback") {
                Write-Response $stream 204 "No Content" ([byte[]]@()) "text/plain; charset=utf-8" (Get-ApiHeaders)
                continue
            }

            if ($method -eq "GET" -and ($path -eq "" -or $path -eq "index.html")) {
                Send-FileResponse $stream (Join-Path $publicDir "index.html")
                continue
            }

            if ($method -eq "GET" -and ($path -eq "admin" -or $path -eq "admin.html")) {
                Send-FileResponse $stream (Join-Path $publicDir "admin.html")
                continue
            }

            if ($path -eq "api/feedback" -and $method -eq "GET") {
                if ($headers["x-admin-token"] -ne $adminToken) {
                    Send-JsonResponse $stream 401 "Unauthorized" @{ error = "Unauthorized." } (Get-ApiHeaders)
                    continue
                }

                try {
                    Send-JsonResponse $stream 200 "OK" @(Read-Feedback) (Get-ApiHeaders)
                } catch {
                    Send-JsonResponse $stream 500 "Internal Server Error" @{ error = "Failed to load feedback." } (Get-ApiHeaders)
                }
                continue
            }

            if ($path -eq "api/feedback" -and $method -eq "POST") {
                try {
                    $payload = $body | ConvertFrom-Json

                    if ([string]::IsNullOrWhiteSpace($payload.name) -or [string]::IsNullOrWhiteSpace($payload.message) -or [string]::IsNullOrWhiteSpace([string]$payload.rating)) {
                        Send-JsonResponse $stream 400 "Bad Request" @{ error = "Name, rating, and message are required." } (Get-ApiHeaders)
                        continue
                    }

                    $entry = [PSCustomObject]@{
                        id        = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
                        name      = [string]$payload.name
                        phone     = [string]$payload.phone
                        rating    = [string]$payload.rating
                        message   = [string]$payload.message
                        createdAt = [DateTime]::UtcNow.ToString("o")
                    }

                    $existing = Read-Feedback
                    $updated = @($entry) + @($existing)
                    Write-Feedback $updated

                    Send-JsonResponse $stream 201 "Created" @{ ok = $true; entry = $entry } (Get-ApiHeaders)
                } catch {
                    Send-JsonResponse $stream 500 "Internal Server Error" @{ error = "Failed to save feedback." } (Get-ApiHeaders)
                }
                continue
            }

            $resolvedPath = Join-Path $publicDir $path
            $fullPublic = [System.IO.Path]::GetFullPath($publicDir)
            $fullResolved = [System.IO.Path]::GetFullPath($resolvedPath)

            if ($fullResolved.StartsWith($fullPublic, [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $fullResolved) -and -not (Get-Item $fullResolved).PSIsContainer) {
                Send-FileResponse $stream $fullResolved
                continue
            }

            Send-JsonResponse $stream 404 "Not Found" @{ error = "Not found." }
        } catch {
            try {
                if ($stream) {
                    Send-JsonResponse $stream 500 "Internal Server Error" @{ error = "Server error." }
                }
            } catch {
            }
        } finally {
            if ($reader) {
                $reader.Dispose()
            }

            if ($stream) {
                $stream.Dispose()
            }

            $client.Dispose()
        }
    }
}
finally {
    $listener.Stop()
}
