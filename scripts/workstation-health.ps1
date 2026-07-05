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
$dotfilesLib = Join-Path $root "dotfiles\lib"
. (Join-Path $dotfilesLib "common.ps1")
. (Join-Path $dotfilesLib "config-links.ps1")

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

$expectedDirs = @(
    "dotfiles",
    "tools",
    "projects",
    "hedglen-profile"
)

foreach ($d in $expectedDirs) {
    $p = Join-Path $root $d
    if (Test-Path $p) {
        OK "$d present"
    } else {
        Warn "$d missing (optional or not yet created)"
    }
}

$dotfilesScripts = Join-Path $root "dotfiles\scripts"
if (Test-Path $dotfilesScripts) {
    OK "dotfiles/scripts present"
} else {
    Warn "dotfiles/scripts missing (optional or not yet created)"
}

$dotfilesNotes = Join-Path $root "dotfiles\notes"
if (Test-Path $dotfilesNotes) {
    OK "dotfiles/notes present"
} else {
    Warn "dotfiles/notes missing (optional or not yet created)"
}

$dotfilesDirForLayout = Join-Path $root "dotfiles"
$mo = Join-Path $dotfilesDirForLayout "projects\media-organizer"
$yt = Join-Path $dotfilesDirForLayout "projects\ytdl"
if (Test-Path $mo) {
    OK "dotfiles/projects/media-organizer present"
    $moPy = Join-Path $mo ".venv\Scripts\python.exe"
    if (Test-Path $moPy) { OK "media-organizer .venv present" } else { Warn "media-organizer .venv missing (run install.ps1 without -NoPythonProjects)" }
} else {
    Warn "dotfiles/projects/media-organizer missing"
}
if (Test-Path $yt) {
    OK "dotfiles/projects/ytdl present"
    $ytPy = Join-Path $yt ".venv\Scripts\python.exe"
    if (Test-Path $ytPy) { OK "ytdl .venv present" } else { Warn "ytdl .venv missing (run install.ps1 without -NoPythonProjects)" }
} else {
    Warn "dotfiles/projects/ytdl missing"
}

$transPy = Join-Path $root "tools\transcribe-env\Scripts\python.exe"
if (Test-Path $transPy) {
    OK "tools/transcribe-env venv present"
} else {
    Warn "tools/transcribe-env venv missing (run install.ps1 without -NoPythonProjects; Whisper deps are a large download)"
}

$mpvBundled = Join-Path $dotfilesDirForLayout "mpv-config"
if (Test-Path $mpvBundled) {
    OK "dotfiles/mpv-config present"
} else {
    Warn "dotfiles/mpv-config missing"
}

$weztermHelpersDir = Join-Path $dotfilesDirForLayout "wezterm"
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
                    OK "tools\mpv\portable_config → dotfiles\mpv-config"
                } else {
                    Warn "tools\mpv\portable_config junction target is '$got' (expected $mpvCfgFull)"
                }
            } else {
                Warn "tools\mpv\portable_config exists but is not a junction (expected → dotfiles\mpv-config)"
            }
        } catch {
            Warn "Could not inspect tools\mpv\portable_config: $_"
        }
    } else {
        Warn "tools\mpv\portable_config missing (run dotfiles\install.ps1 after mpv is in tools\mpv)"
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

# workstation\scripts / workstation\projects → dotfiles (when install.ps1 created junctions)
$dfsRoot = Join-Path $root "dotfiles"
foreach ($jx in @(
        @{ Leg = "scripts";  Sub = "scripts";  Label = "workstation\scripts → dotfiles\scripts" },
        @{ Leg = "projects"; Sub = "projects"; Label = "workstation\projects → dotfiles\projects" }
    )) {
    $legPath = Join-Path $root $jx.Leg
    $wantTgtPath = Join-Path $dfsRoot $jx.Sub
    if (-not (Test-Path $legPath)) {
        Warn "$($jx.Label): path missing (optional; install.ps1 creates junction if path is free)"
        continue
    }
    try {
        $li = Get-Item -LiteralPath $legPath -Force -ErrorAction Stop
        if (-not ($li.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Warn "workstation\$($jx.Leg) exists but is not a junction (expected → dotfiles\$($jx.Sub))"
            continue
        }
        $tgt = $li.Target
        if ($null -eq $tgt) {
            Warn "workstation\$($jx.Leg): could not read junction target"
            continue
        }
        if ($tgt -is [array]) { $tgt = $tgt[0] }
        $normTgt = [System.IO.Path]::GetFullPath($tgt.TrimEnd('\', '/'))
        if (Test-Path $wantTgtPath) {
            $normWant = [System.IO.Path]::GetFullPath($wantTgtPath.TrimEnd('\', '/'))
            if ($normTgt -ieq $normWant) {
                OK $jx.Label
            } else {
                Warn "workstation\$($jx.Leg) junction target is '$tgt' (expected '$wantTgtPath')"
            }
        } else {
            OK "workstation\$($jx.Leg) is a junction → $tgt"
        }
    } catch {
        Warn "Could not inspect workstation\$($jx.Leg): $_"
    }
}

Step "Checking core tools on PATH"

$commands = @("git", "winget", "code", "pwsh", "AutoHotkey.exe", "claude")
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

Step "Dry-run: dotfiles/install.ps1"

$dotfilesDir = Join-Path $root "dotfiles"
$dotfilesScript = Join-Path $dotfilesDir "install.ps1"
if (Test-Path $dotfilesScript) {
    try {
        Push-Location $dotfilesDir
        if ($Verbose) {
            .\install.ps1 -DryRun -NoElevate
        } else {
            .\install.ps1 -DryRun -NoElevate | Out-Null
        }
        OK "dotfiles/install.ps1 -DryRun completed"
    } catch {
        Fail "dotfiles/install.ps1 -DryRun failed: $_"
        $errors += "DotfilesDryRunFailed"
    } finally {
        Pop-Location
    }
} else {
    Fail "dotfiles/install.ps1 not found at $dotfilesScript"
    $errors += "DotfilesMissing"
}

Step "Dry-run: dotfiles/mpv-config/install.ps1"

$mpvConfigDir = Join-Path $root "dotfiles\mpv-config"
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
        OK "dotfiles/mpv-config/install.ps1 -DryRun completed"
    } catch {
        Warn "dotfiles/mpv-config/install.ps1 -DryRun failed: $_"
        $errors += "MpvDryRunFailed"
    } finally {
        Pop-Location
    }
} else {
    Warn "dotfiles/mpv-config/install.ps1 not found at $mpvConfigScript"
}

Step "Spot-check key configs (from lib/config-links.ps1 map)"

foreach ($link in (Get-ConfigLinks -DotfilesDir (Join-Path $root "dotfiles"))) {
    $src  = Join-Path (Join-Path $root "dotfiles") $link.src
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
            Warn "${desc}: present but does not dot-source dotfiles profile"
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
                OK "${desc}: linked -> dotfiles"
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

Step "Workstation root docs"

$claudeMd = Join-Path $root "CLAUDE.md"
if (Test-Path -LiteralPath $claudeMd) {
    $claudeMdSrc = Join-Path $root "dotfiles\claude\CLAUDE.md"
    if ((Test-Path -LiteralPath $claudeMdSrc) -and
        ((Get-Content $claudeMd -Raw) -ne (Get-Content $claudeMdSrc -Raw))) {
        Warn "workstation\CLAUDE.md differs from dotfiles claude\CLAUDE.md"
    } else {
        OK "workstation\CLAUDE.md present"
    }
} else {
    Warn "workstation\CLAUDE.md missing (run install.ps1 to restore from dotfiles)"
}

Step "Checking git repo health"

$gitRepos = @(
    "dotfiles",
    "hedglen-profile"
)

foreach ($r in $gitRepos) {
    $repoPath = Join-Path $root $r
    $name     = Split-Path $r -Leaf
    if (-not (Test-Path $repoPath)) {
        Warn "$name not found at $repoPath"
        continue
    }
    $gitDir = Join-Path $repoPath ".git"
    if (-not (Test-Path $gitDir)) {
        Warn "${name}: directory exists but is not a git repo"
        continue
    }
    try {
        Push-Location $repoPath
        $dirty = git status --porcelain 2>$null
        if ($dirty) {
            Warn "${name}: uncommitted changes"
            $errors += "Dirty:${name}"
        } else {
            OK "${name}: clean"
        }
    } finally {
        Pop-Location
    }
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

