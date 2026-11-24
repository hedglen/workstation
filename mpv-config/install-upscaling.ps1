# Upgrade only the adaptive renderer and its shader; preserve local settings.
[CmdletBinding()]
param([switch]$Install)
$ErrorActionPreference = 'Stop'
$config = Join-Path $env:APPDATA 'mpv'
$source = Join-Path $PSScriptRoot 'scripts/adaptive-render.lua'
$script = Join-Path $config 'scripts/adaptive-render.lua'
$shader = Join-Path $config 'shaders/FSRCNNX_x2_8-0-4-1.glsl'
$url = 'https://github.com/igv/FSRCNN-TensorFlow/releases/download/1.1/FSRCNNX_x2_8-0-4-1.glsl'
if (-not (Test-Path (Join-Path $config 'mpv.conf') -PathType Leaf)) { throw 'Existing AppData mpv.conf not found.' }
$exe = @(Get-Command mpv -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -match '(?i)mpv\.(exe|com)$' })
if (-not $exe.Count) { throw 'mpv not found on PATH.' }
foreach ($e in $exe) {
    if (Test-Path (Join-Path (Split-Path $e.Source -Parent) 'portable_config')) { throw 'Portable configuration overrides AppData. Run install.ps1 -Mode Diagnose.' }
}
foreach ($p in @($config,(Join-Path $config 'scripts'),(Join-Path $config 'shaders'),$script,$shader)) {
    if ((Test-Path -LiteralPath $p) -and ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Refusing to edit linked path: $p" }
}
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'Missing repository adaptive-render.lua.' }
Write-Host "Adaptive renderer: $script"
Write-Host "Shader: $shader"
if (-not $Install) { Write-Host 'Preview only. Use -Install to activate automatic rendering.'; exit 0 }
if (Get-Process mpv -ErrorAction SilentlyContinue) { throw 'Close mpv before installing.' }
$temp = Join-Path $env:TEMP ('FSRCNNX-' + [guid]::NewGuid().ToString('N') + '.glsl')
try {
    Invoke-WebRequest -Uri $url -OutFile $temp
    if ((Get-Item $temp).Length -lt 1024 -or ((Get-Content $temp -TotalCount 25 | Out-String) -notmatch '//!HOOK|//!DESC')) { throw 'Invalid shader download.' }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    foreach ($p in @($shader,$script)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $p -Parent) | Out-Null
        if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination "$p.backup.$stamp" }
    }
    Copy-Item -LiteralPath $temp -Destination $shader -Force
    Copy-Item -LiteralPath $source -Destination $script -Force
    Write-Host 'Adaptive rendering installed. Restart mpv. Ctrl+F8: Auto/Reference; Ctrl+F9: cycle modes.' -ForegroundColor Green
} finally { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
