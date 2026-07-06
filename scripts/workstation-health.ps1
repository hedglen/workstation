<# 
  workstation-health.ps1
  Quick health check for the hedglen workstation layout and core tooling.
  Safe to run often; uses -DryRun for heavy installers.
#>

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

function Step  { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function OK    { param([string]$Msg) Write-Host "   OK  $Msg" -ForegroundColor Green }
function Warn  { param([string]$Msg) Write-Host "   !!  $Msg" -ForegroundColor Yellow }
function Fail  { param([string]$Msg) Write-Host "   XX  $Msg" -ForegroundColor Red }

$root   = Join-Path $HOME "workstation"
$errors = @()

# Shared config map — spot-checks below stay in lockstep with the installers
$repoLib = Join-Path $root "lib"
. (Join-Path $repoLib "common.ps1")
. (Join-Path $repoLib "config-links.ps1")

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   hedglen workstation — health check" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""

Step "Validating canonical layout"

if (-not (Test-Path $root)) {
    Fail "Canonical root not found at $root"
    $errors += "RootMissing"
} else {
    OK "Root exists: $root"
}

if (-not (Test-Path (Join-Path $root ".git"))) {
    Fail "workstation is not a git repo (expected .git at $root)"
    $errors += "RepoMissing"
} else {
    OK "workstation is the git repo"
}

$expectedDirs = @(
    "apps",
    "docs",
    "lib",
    "notes",
    "projects",
    "scripts",
    "tools",
    "wezterm",
    "wsl"
)

foreach ($d in $expectedDirs) {
    $p = Join-Path $root $d
    if (Test-Path $p) {
        OK "$d present"
    } else {
        Warn "$d missing (optional or not yet created)"
    }
}

$mo = Join-Path $root "projects\media-organizer"
$yt = Join-Path $root "projects\ytdl"
if (Test-Path $mo) {
    OK "projects/media-organizer present"
    $moPy = Join-Path $mo ".venv\Scripts\python.exe"
    if (Test-Path $moPy) { OK "media-organizer .venv present" } else { Warn "media-organizer .venv missing (run install.ps1 without -NoPythonProjects)" }
} else {
    Warn "projects/media-organizer missing"
}
if (Test-Path $yt) {
    OK "projects/ytdl present"
    $ytPy = Join-Path $yt ".venv\Scripts\python.exe"
    if (Test-Path $ytPy) { OK "ytdl .venv present" } else { Warn "ytdl .venv missing (run install.ps1 without -NoPythonProjects)" }
} else {
    Warn "projects/ytdl missing"
}

$transPy = Join-Path $root "tools\transcribe-env\Scripts\python.exe"
if (Test-Path $transPy) {
    OK "tools/transcribe-env venv present"
} else {
    Warn "tools/transcribe-env venv missing (run install.ps1 without -NoPythonProjects; Whisper deps are a large download)"
}

$mpvBundled = Join-Path $root "mpv-config"
if (Test-Path $mpvBundled) {
    OK "mpv-config present"
} else {
    Warn "mpv-config missing"
}

$weztermHelpersDir = Join-Path $root "wezterm"
$wslHelperPath = Join-Path $weztermHelpersDir "wsl-helper.sh"
if (Test-Path $wslHelperPath) {
    OK "wezterm/wsl-helper.sh present"
} else {
    Warn "wezterm/wsl-helper.sh missing (required for WSL right pane)"
    $errors += "WezTermHelperMissing:wsl-helper.sh"
}

$mpvTools     = Join-Path $root "tools\mpv"
$portableCfg  = Join-Path $mpvTools "portable_config"
$mpvCfgFull   = [System.IO.Path]::GetFullPath($mpvBundled)
if (Test-Path $mpvTools) {
    if (Test-Path $portableCfg) {
        try {
            $pc = Get-Item -LiteralPath $portableCfg -Force -ErrorAction Stop
            if ($pc.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $pt = $pc.Target
                if ($pt -is [array] -and $pt.Count -gt 0) { $pt = $pt[0] }
                $got = [System.IO.Path]::GetFullPath($pt.TrimEnd('\', '/'))
                if ($got -ieq $mpvCfgFull) {
                    OK "tools\mpv\portable_config → mpv-config"
                } else {
                    Warn "tools\mpv\portable_config junction target is '$got' (expected $mpvCfgFull)"
                }
            } else {
                Warn "tools\mpv\portable_config exists but is not a junction (expected → mpv-config)"
            }
        } catch {
            Warn "Could not inspect tools\mpv\portable_config: $_"
        }
    } else {
        Warn "tools\mpv\portable_config missing (run install.ps1 after mpv is in tools\mpv)"
    }
}

Step "Checking compatibility junctions"

$compatTools = Join-Path $env:USERPROFILE "tools"
if (Test-Path $compatTools) {
    try {
        $item = Get-Item $compatTools -ErrorAction Stop
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $target = (Get-Item $compatTools).Target
            if ($target -eq "$root\tools") {
                OK "%USERPROFILE%\tools is a junction → $root\tools"
            } else {
                Warn "%USERPROFILE%\tools points to '$target' (expected $root\tools)"
            }
        } else {
            Warn "%USERPROFILE%\tools exists but is not a junction"
        }
    } catch {
        Warn "Unable to inspect %USERPROFILE%\tools: $_"
    }
} else {
    Warn "%USERPROFILE%\tools not present (compat junction optional)"
}

Step "Checking core tools on PATH"

$commands = @("git", "winget", "code", "pwsh", "claude")
foreach ($c in $commands) {
    if (Get-Command $c -ErrorAction SilentlyContinue) {
        OK "$c found"
    } else {
        Warn "$c not found"
        if ($c -in @("git", "winget")) {
            $errors += "Missing:$c"
        }
    }
}

# AutoHotkey: the winget user-scope install is not on PATH — probe known locations
$ahkExe = Get-AutoHotkeyExe
if ($ahkExe) {
    OK "AutoHotkey found ($ahkExe)"
    $ahkRun = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -ErrorAction SilentlyContinue).AutoHotkey
    if ($ahkRun) {
        OK "AutoHotkey registered for startup"
    } else {
        Warn "AutoHotkey not registered for startup (run install.ps1)"
    }
} else {
    Warn "AutoHotkey not found"
}

Step "Dry-run: install.ps1"

$installScript = Join-Path $root "install.ps1"
if (Test-Path $installScript) {
    try {
        Push-Location $root
        if ($Verbose) {
            .\install.ps1 -DryRun -NoElevate
        } else {
            .\install.ps1 -DryRun -NoElevate | Out-Null
        }
        OK "install.ps1 -DryRun completed"
    } catch {
        Fail "install.ps1 -DryRun failed: $_"
        $errors += "InstallDryRunFailed"
    } finally {
        Pop-Location
    }
} else {
    Fail "install.ps1 not found at $installScript"
    $errors += "InstallMissing"
}

Step "Dry-run: mpv-config/install.ps1"

$mpvConfigDir = Join-Path $root "mpv-config"
$mpvConfigScript = Join-Path $mpvConfigDir "install.ps1"
$mpvInstallDir = "$env:USERPROFILE\workstation\tools\mpv"

if (Test-Path $mpvConfigScript) {
    try {
        Push-Location $mpvConfigDir
        if ($Verbose) {
            .\install.ps1 -DryRun -InstallDir $mpvInstallDir
        } else {
            .\install.ps1 -DryRun -InstallDir $mpvInstallDir | Out-Null
        }
        OK "mpv-config/install.ps1 -DryRun completed"
    } catch {
        Warn "mpv-config/install.ps1 -DryRun failed: $_"
        $errors += "MpvDryRunFailed"
    } finally {
        Pop-Location
    }
} else {
    Warn "mpv-config/install.ps1 not found at $mpvConfigScript"
}

Step "Spot-check key configs (from lib/config-links.ps1 map)"

foreach ($link in (Get-ConfigLinks -WorkstationDir $root)) {
    $src  = Join-Path $root $link.src
    $dst  = $link.dst
    $desc = $link.desc

    if (-not (Test-Path -LiteralPath $dst)) {
        Warn "${desc}: not found ($dst)"
        continue
    }

    $item = Get-Item -LiteralPath $dst -Force
    if ($link.loader) {
        # Must be a REAL file (a symlink here breaks profile loading — see the map)
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Warn "${desc}: is a symlink — should be a loader stub (run install.ps1 or sync-dots)"
        } elseif ((Get-Content -LiteralPath $dst -Raw -ErrorAction SilentlyContinue).Trim() -eq ". `"$src`"") {
            OK "${desc}: loader stub in place"
        } else {
            Warn "${desc}: present but does not dot-source the repo profile"
        }
        continue
    }

    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $target = $item.Target
        if ($target -is [array] -and $target.Count -gt 0) { $target = $target[0] }
        try {
            $resolved = [System.IO.Path]::GetFullPath($target.TrimEnd('\', '/'))
            $expected = [System.IO.Path]::GetFullPath($src)
            if ($resolved -ieq $expected) {
                OK "${desc}: linked -> repo"
            } else {
                Warn "${desc}: points to '$resolved' (expected '$expected')"
            }
        } catch {
            Warn "${desc}: could not resolve link target: $_"
        }
    } else {
        Warn "${desc}: present but not a link (copy fallback? re-run install.ps1 as admin)"
    }
}

# Superseded by the ~/.config/wezterm junction — installers remove this file
if (Test-Path -LiteralPath "$HOME\.wezterm.lua") {
    Warn "legacy ~/.wezterm.lua still present (run sync-dots to remove)"
} else {
    OK "no legacy ~/.wezterm.lua"
}

Step "Checking git repo health"

$dirty = git -C $root status --porcelain 2>$null
if ($dirty) {
    Warn "workstation: uncommitted changes"
    $errors += "Dirty:workstation"
} else {
    OK "workstation: clean"
}

Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "   Health check PASSED" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "   Health check completed with issues" -ForegroundColor Red
    Write-Host "   Details: $($errors -join ', ')" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    exit 1
}

