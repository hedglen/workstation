# =============================================================================
#   lib/common.ps1
#   Shared logging + environment helpers for install.ps1, maintenance/update.ps1,
#   and scripts/workstation-health.ps1. Dot-source; do not run directly.
# =============================================================================

function Write-Step { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$Msg) Write-Host "   OK  $Msg" -ForegroundColor Green }
function Write-Skip { param([string]$Msg) Write-Host "   --  $Msg" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Msg) Write-Host "   !!  $Msg" -ForegroundColor Yellow }

function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Prefer a real AutoHotkey64.exe. The WindowsApps\AutoHotkey.exe app-alias shim
# runs launcher.ahk and often throws "cannot find path" at startup. The winget
# user-scope install lands under LOCALAPPDATA\Programs\AutoHotkey\v2 and is NOT
# on PATH.
function Get-AutoHotkeyExe {
    $candidates = @(
        "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey64.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\AutoHotkey64.exe"
    )
    $exe = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $exe) {
        $cmd = Get-Command AutoHotkey64.exe, AutoHotkey.exe -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source -notmatch '\\WindowsApps\\') { $exe = $cmd.Source }
    }
    $exe
}
