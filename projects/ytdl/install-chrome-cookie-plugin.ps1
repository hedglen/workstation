# Install yt-dlp ChromeCookieUnlock plugin (WinGet / standalone yt-dlp reads %APPDATA%\yt-dlp\plugins).
# Run once:  pwsh -File install-chrome-cookie-plugin.ps1
# https://github.com/seproDev/yt-dlp-ChromeCookieUnlock

$ErrorActionPreference = 'Stop'
$pluginsRoot = Join-Path $env:APPDATA 'yt-dlp\plugins'
$extractName = 'yt-dlp-ChromeCookieUnlock-main'
$finalName = 'ChromeCookieUnlock'
$zip = Join-Path $env:TEMP 'ChromeCookieUnlock.zip'
$uri = 'https://github.com/seproDev/yt-dlp-ChromeCookieUnlock/archive/refs/heads/main.zip'

New-Item -ItemType Directory -Path $pluginsRoot -Force | Out-Null
$dest = Join-Path $pluginsRoot $finalName
if (Test-Path $dest) {
    Remove-Item $dest -Recurse -Force
}

Write-Host "Downloading ChromeCookieUnlock..."
Invoke-WebRequest -Uri $uri -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $pluginsRoot -Force
Remove-Item $zip -Force

$extracted = Join-Path $pluginsRoot $extractName
if (-not (Test-Path $extracted)) {
    Write-Error "Extract folder not found: $extractName"
}
Rename-Item -Path $extracted -NewName $finalName

$check = Join-Path $dest 'yt_dlp_plugins'
if (-not (Test-Path $check)) {
    Write-Error "Plugin layout invalid (missing yt_dlp_plugins)."
}

Write-Host "Installed to: $dest"
Write-Host "Note: unlock often still fails on newer Chrome; if so use cookies.txt in the ytdl folder (see README)."
