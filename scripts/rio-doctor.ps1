# =============================================================================
#   rio-doctor.ps1 — diagnose and fix Rio terminal not showing a window.
#
#   Rio draws with wgpu (WebGPU); on some GPU/driver combos the automatic
#   backend pick creates a window that crashes or never presents. This script
#   tries each renderer backend in turn, keeps the first one you confirm
#   works, and collects crash output if none do.
#
#   Usage:  & "$HOME\workstation\scripts\rio-doctor.ps1"
# =============================================================================

[CmdletBinding()]
param(
    # Seconds to let Rio live before deciding it survived startup
    [int]$SurviveSeconds = 5
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "    $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "    $msg" -ForegroundColor Red }

# --- Locate rio.exe --------------------------------------------------------
Write-Step "Locating rio.exe"
$rio = (Get-Command rio -ErrorAction SilentlyContinue)?.Source
if (-not $rio) {
    $candidates = @(
        "$env:LOCALAPPDATA\Programs\rio\rio.exe",
        "$env:ProgramFiles\Rio\rio.exe"
    )
    $rio = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $rio) {
    $found = Get-ChildItem "$env:LOCALAPPDATA\Programs" -Recurse -Filter rio.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($found) { $rio = $found.FullName }
}
if (-not $rio) {
    Write-Fail "rio.exe not found. Is it installed? Try: winget install -e --id raphamorim.rio"
    exit 1
}
Write-OK "Found: $rio"

# --- Prepare config dir, back up whatever is there now ----------------------
$configDir  = Join-Path $env:LOCALAPPDATA 'rio'
$configPath = Join-Path $configDir 'config.toml'
New-Item -ItemType Directory -Force $configDir | Out-Null

if (Test-Path $configPath) {
    $backup = "$configPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $configPath $backup
    Write-OK "Backed up existing config to $backup"
}

# --- Kill any stuck instances ------------------------------------------------
Get-Process rio -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# --- Try each backend --------------------------------------------------------
# Order: most likely to work on Windows/NVIDIA first. The last attempt pairs
# Automatic with low-power mode, which picks a different GPU adapter.
$attempts = @(
    @{ Backend = 'Dx12';      Performance = $null  },
    @{ Backend = 'GL';        Performance = $null  },
    @{ Backend = 'Vulkan';    Performance = $null  },
    @{ Backend = 'Dx11';      Performance = $null  },
    @{ Backend = 'Automatic'; Performance = 'Low'  }
)

$stderrDir = Join-Path $env:TEMP 'rio-doctor'
New-Item -ItemType Directory -Force $stderrDir | Out-Null
$winner = $null

foreach ($attempt in $attempts) {
    $label = $attempt.Backend + $(if ($attempt.Performance) { " + performance=$($attempt.Performance)" })
    Write-Step "Trying renderer backend: $label"

    $config = @("[developer]", 'enable-log-file = true', 'log-level = "DEBUG"', '', '[renderer]',
                "backend = `"$($attempt.Backend)`"")
    if ($attempt.Performance) { $config += "performance = `"$($attempt.Performance)`"" }
    Set-Content -Path $configPath -Value ($config -join "`n") -Encoding UTF8

    $errFile = Join-Path $stderrDir "rio-$($attempt.Backend).err.txt"
    $outFile = Join-Path $stderrDir "rio-$($attempt.Backend).out.txt"
    $proc = Start-Process -FilePath $rio -PassThru `
        -RedirectStandardError $errFile -RedirectStandardOutput $outFile

    Start-Sleep -Seconds $SurviveSeconds
    $proc.Refresh()

    if ($proc.HasExited) {
        Write-Warn "Rio exited after launch (code $($proc.ExitCode)) — backend failed."
        continue
    }

    Write-OK "Rio is still running. Look at your screen."
    $answer = Read-Host "    Can you see a working Rio window? (y/n)"
    if ($answer -match '^[Yy]') {
        $winner = $label
        break
    }

    Write-Warn "Window not visible — killing and trying the next backend."
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# --- Verdict -----------------------------------------------------------------
Write-Host ''
if ($winner) {
    Write-Step "Fixed: Rio works with backend $winner"
    Write-OK "Config saved at $configPath — Rio will use this backend from now on."
    Write-OK "Your previous config (if any) is next to it as a .bak file; merge any settings you want back."
    exit 0
}

Write-Step "No backend produced a visible window. Collected evidence:"
Get-ChildItem $stderrDir -Filter '*.err.txt' | ForEach-Object {
    if ($_.Length -gt 0) {
        Write-Warn "--- $($_.Name) ---"
        Get-Content $_.FullName -Tail 15 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
}
$log = Get-ChildItem $configDir -Filter '*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($log) {
    Write-Warn "--- tail of $($log.Name) ---"
    Get-Content $log.FullName -Tail 25 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
}

Write-Host ''
Write-Warn "Next steps, in order:"
Write-Warn " 1. Update your NVIDIA driver, then re-run this script."
Write-Warn " 2. Settings > System > Display > Graphics: add rio.exe, set High performance, re-run."
Write-Warn " 3. Still dead? File the output above at https://github.com/raphamorim/rio/issues"
exit 1
