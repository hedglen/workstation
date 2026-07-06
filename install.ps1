# =============================================================================
#   workstation/install.ps1
#   Bootstrap a fresh Windows machine from scratch.
#   https://github.com/hedglen/workstation
#
#   Usage:
#     irm https://raw.githubusercontent.com/hedglen/workstation/master/install.ps1 | iex
#
#   Flags:
#     -AppsOnly     Skip most setup/config steps; still installs apps
#     -ConfigsOnly  Only symlink config files
#     -NoApps    Skip winget and Scoop installs
#     -NoScoop   Skip Scoop only (winget installs still run)
#     -NoPythonProjects  Skip venv setup for projects\media-organizer and projects\ytdl
#     -NoElevate Skip auto-elevation (single UAC at start)
#     -DryRun    Preview what would happen without doing anything
#
#   Scoop: if missing, get.scoop.sh is run automatically, then packages from apps\scoop-packages.json.
# =============================================================================

param(
    [switch]$AppsOnly,
    [switch]$ConfigsOnly,
    [switch]$NoApps,
    [switch]$NoScoop,
    [switch]$NoPythonProjects,
    [switch]$NoElevate,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$WorkstationDir = $PSScriptRoot
# irm ... | iex has no script path; PSScriptRoot can be empty or whitespace.
$bootstrapFromIex = [string]::IsNullOrWhiteSpace($WorkstationDir)
if ($bootstrapFromIex) {
    $WorkstationDir = "$HOME\workstation"
}

# Shared helpers live in lib\. During an irm|iex bootstrap the repo is not
# cloned yet, so fall back to inline loggers until the local re-invoke.
if (Test-Path (Join-Path $WorkstationDir "lib\common.ps1")) {
    . (Join-Path $WorkstationDir "lib\common.ps1")
    . (Join-Path $WorkstationDir "lib\config-links.ps1")
    . (Join-Path $WorkstationDir "lib\startup-policy.ps1")
    . (Join-Path $WorkstationDir "lib\fonts.ps1")
    . (Join-Path $WorkstationDir "lib\extensions.ps1")
    . (Join-Path $WorkstationDir "lib\python-projects.ps1")
} else {
    function Write-Step { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
    function Write-OK   { param([string]$Msg) Write-Host "   OK  $Msg" -ForegroundColor Green }
    function Write-Skip { param([string]$Msg) Write-Host "   --  $Msg" -ForegroundColor DarkGray }
    function Write-Warn { param([string]$Msg) Write-Host "   !!  $Msg" -ForegroundColor Yellow }
}

function Install-PCloudIfMissing {
    param([switch]$DryRun)
    $pkgId = "pCloudAG.pCloudDrive"
    if ($DryRun) {
        Write-Skip "Would verify/install $pkgId with hash-mismatch fallback"
        return
    }

    $isInstalled = $false
    try {
        $listOut = (& winget list --id $pkgId -e --accept-source-agreements 2>$null) -join "`n"
        if ($listOut -match [regex]::Escape($pkgId)) { $isInstalled = $true }
    } catch { }
    if ($isInstalled) {
        Write-Skip "$pkgId already installed"
        return
    }

    $commonArgs = @('-e', '--id', $pkgId, '--accept-package-agreements', '--accept-source-agreements')
    $installOut = (& winget install @commonArgs 2>&1)
    if ($LASTEXITCODE -eq 0) {
        Write-OK "$pkgId installed"
        return
    }

    $text = ($installOut | Out-String)
    if ($text -match 'Installer hash does not match' -or $text -match 'hash mismatch') {
        Write-Warn "$pkgId hash mismatch; retrying with override"
        try { & winget settings --enable InstallerHashOverride | Out-Null } catch { }
        $retryOut = (& winget install @commonArgs --ignore-security-hash 2>&1)
        if ($LASTEXITCODE -eq 0) {
            Write-OK "$pkgId installed (hash override)"
        } else {
            Write-Warn "$pkgId install failed even with hash override"
            $retryOut | ForEach-Object { Write-Warn "  $_" }
        }
        return
    }

    Write-Warn "$pkgId install failed"
    $installOut | ForEach-Object { Write-Warn "  $_" }
}

function Initialize-WorkstationLayout {
    param([switch]$DryRun)
    Write-Step "Workstation layout"
    $wsRoot = Join-Path $HOME "workstation"
    if ($DryRun) {
        Write-Skip "Would create $wsRoot if missing"
        return
    }
    New-Item -ItemType Directory -Path $wsRoot -Force | Out-Null
    Write-OK "workstation root ready"
}

# Re-launch elevated once so installers that require admin don't repeatedly prompt.
function Restart-ElevatedIfNeeded {
    param(
        [Parameter(Mandatory)]
        [string] $ScriptPath,
        [switch] $NoElevate
    )
    if ($NoElevate) { return }
    if ($DryRun) { return }   # a preview should never pop UAC
    if (Test-IsAdmin) { return }

    $switches = @()
    if ($AppsOnly) { $switches += '-AppsOnly' }
    if ($ConfigsOnly) { $switches += '-ConfigsOnly' }
    if ($NoApps) { $switches += '-NoApps' }
    if ($NoScoop) { $switches += '-NoScoop' }
    if ($NoPythonProjects) { $switches += '-NoPythonProjects' }
    if ($DryRun) { $switches += '-DryRun' }

    $exePath = (Get-Process -Id $PID).Path
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$ScriptPath`"") + $switches
    Write-Host "Requesting elevation for full bootstrap..." -ForegroundColor Cyan
    Start-Process -FilePath $exePath -Verb RunAs -ArgumentList $argList
    exit
}

if ($bootstrapFromIex) {
    Initialize-WorkstationLayout -DryRun:$DryRun
    # workstation\ may already exist and be non-empty (tools\ is untracked),
    # so hydrate in place instead of `git clone` into the directory.
    if (-not (Test-Path -LiteralPath (Join-Path $WorkstationDir '.git'))) {
        Write-Host "Fetching workstation repo..." -ForegroundColor Cyan
        git -C $WorkstationDir init
        git -C $WorkstationDir remote add origin https://github.com/hedglen/workstation.git
        git -C $WorkstationDir fetch origin
        git -C $WorkstationDir checkout -f -B master origin/master
        git -C $WorkstationDir branch --set-upstream-to=origin/master master
    }
    & "$WorkstationDir\install.ps1" @PSBoundParameters
    exit
}

Initialize-WorkstationLayout -DryRun:$DryRun
Restart-ElevatedIfNeeded -ScriptPath (Join-Path $WorkstationDir 'install.ps1') -NoElevate:$NoElevate

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   workstation installer — hedglen" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
if ($DryRun) { Write-Host "   DRY RUN — no changes will be made" -ForegroundColor Yellow }
Write-Host ""

# =============================================================================
#   1. Prerequisites
# =============================================================================
Write-Step "Checking prerequisites"

$prereqs = @("git", "winget")
foreach ($cmd in $prereqs) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-OK "$cmd found"
    } else {
        Write-Warn "$cmd not found — some steps may fail"
    }
}

# =============================================================================
#   2. Repo layout sanity
# =============================================================================
if (-not $AppsOnly -and -not $ConfigsOnly) {
    # Python helpers (media-organizer, ytdl) ship under projects\
    Write-Step "Projects (projects\)"
    $projectsBundled = Join-Path $WorkstationDir "projects"
    if (Test-Path $projectsBundled) {
        Write-OK "projects directory present"
    } elseif ($DryRun) {
        Write-Skip "Would create: $projectsBundled"
    } else {
        New-Item -ItemType Directory -Path $projectsBundled -Force | Out-Null
        Write-Warn "Created empty projects\ — git pull for media-organizer / ytdl"
    }

    # Utility scripts ship inside this repo (not a separate clone).
    Write-Step "Utility scripts (scripts\)"
    $scriptsDir = Join-Path $WorkstationDir "scripts"
    if (Test-Path $scriptsDir) {
        Write-OK "scripts directory present"
    } elseif ($DryRun) {
        Write-Skip "Would create: $scriptsDir"
    } else {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        Write-Warn "Created empty scripts\ — git pull for the full script tree"
    }
}

# =============================================================================
#   3. Install apps (single source: this repo only — no %USERPROFILE%\Documents copies)
# =============================================================================
if (-not $ConfigsOnly -and -not $NoApps) {
    Write-Step "Installing apps from winget"

    # Manifest is JSONC (// comments), so it is installed per-ID here rather than
    # via `winget import`, which requires strict schema JSON.
    $pkgFile = Join-Path $WorkstationDir "apps\winget-packages.json"
    if (Test-Path $pkgFile) {
        $wingetIds = @((Get-Content $pkgFile -Raw | ConvertFrom-Json).packages | Where-Object { $_ })
        if ($DryRun) {
            Write-Skip "Would winget install $($wingetIds.Count) packages from apps\winget-packages.json"
        } else {
            $failed = New-Object System.Collections.Generic.List[string]
            foreach ($id in $wingetIds) {
                & winget install --id $id -e --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
                # 0 = installed; -1978335189 = no applicable update; -1978335135 = already installed
                if ($LASTEXITCODE -in 0, -1978335189, -1978335135) {
                    Write-OK $id
                } else {
                    Write-Warn "$id failed (exit $LASTEXITCODE)"
                    $failed.Add($id)
                }
            }
            if ($failed.Count -gt 0) {
                Write-Warn ("{0} package(s) failed: {1}" -f $failed.Count, ($failed -join ', '))
                Write-Warn "Retry one with: winget install --id <PackageId> -e"
            }
            Install-PCloudIfMissing
        }
    } else {
        Write-Warn "apps\winget-packages.json not found — skipping"
    }

    Write-Step "Installing Scoop CLI packages"

    $scoopFile = Join-Path $WorkstationDir "apps\scoop-packages.json"
    if ($NoScoop) {
        Write-Skip "Skipping Scoop (-NoScoop)"
    } elseif (-not (Test-Path $scoopFile)) {
        Write-Warn "apps\scoop-packages.json not found — skipping Scoop"
    } else {
        $haveScoop = [bool](Get-Command scoop -ErrorAction SilentlyContinue)
        if (-not $haveScoop) {
            if ($DryRun) {
                Write-Skip "Would install Scoop (get.scoop.sh) then scoop install …"
            } else {
                Write-Step "Bootstrapping Scoop (not on PATH)"
                try {
                    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
                    $prevEA = $ErrorActionPreference
                    $ErrorActionPreference = 'Continue'
                    Invoke-Expression (Invoke-RestMethod -Uri https://get.scoop.sh -UseBasicParsing)
                    $ErrorActionPreference = $prevEA
                    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [System.Environment]::GetEnvironmentVariable('Path', 'User')
                    $haveScoop = [bool](Get-Command scoop -ErrorAction SilentlyContinue)
                    if ($haveScoop) {
                        Write-OK "Scoop installed"
                    } else {
                        Write-Warn "Scoop bootstrap finished but scoop is still not on PATH — open a new terminal or add shims to PATH"
                    }
                } catch {
                    Write-Warn "Scoop bootstrap failed — $_"
                }
            }
        }

        if (-not $haveScoop -and -not $DryRun) {
            Write-Warn "Scoop not on PATH — skipping apps\scoop-packages.json"
        } elseif ($DryRun -and $haveScoop) {
            Write-Skip "Would run: scoop bucket add extras; scoop install <names from apps\scoop-packages.json>"
        } elseif (-not $DryRun -and $haveScoop) {
            # extras bucket is needed for lazygit
            $buckets = @(& scoop bucket list 2>$null | ForEach-Object { ($_ -split '\s+')[0] })
            if ($buckets -notcontains 'extras') {
                & scoop bucket add extras
                if ($LASTEXITCODE -eq 0) { Write-OK "scoop bucket add extras" } else { Write-Warn "scoop bucket add extras exited $LASTEXITCODE" }
            }
            $names = @((Get-Content $scoopFile -Raw | ConvertFrom-Json).packages | Where-Object { $_ })
            if ($names.Count -eq 0) {
                Write-Skip "No package names in scoop-packages.json"
            } else {
                $prevEA = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                & scoop install @names
                $exit = $LASTEXITCODE
                $ErrorActionPreference = $prevEA
                if ($exit -eq 0) {
                    Write-OK "Scoop install ($($names.Count) packages)"
                } else {
                    Write-Warn "scoop install exited $exit (some apps may already be installed)"
                }
            }
        }
    }

    # Native build (not winget): auto-updates in the background and avoids a
    # dual-install conflict with an existing native claude.
    Write-Step "Claude Code CLI"
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Skip "claude already installed"
    } elseif ($DryRun) {
        Write-Skip "Would install Claude Code (irm https://claude.ai/install.ps1 | iex)"
    } else {
        try {
            $prevEA = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            Invoke-Expression (Invoke-RestMethod -Uri https://claude.ai/install.ps1 -UseBasicParsing)
            $ErrorActionPreference = $prevEA
            $env:Path = "$env:USERPROFILE\.local\bin;" + $env:Path
            if (Get-Command claude -ErrorAction SilentlyContinue) {
                Write-OK "Claude Code installed (run 'claude' to log in)"
            } else {
                Write-Warn "Claude Code installer finished but claude is not on PATH — open a new terminal"
            }
        } catch {
            Write-Warn "Claude Code install failed — $_"
            Write-Warn "  Install manually: irm https://claude.ai/install.ps1 | iex"
        }
    }
}

# =============================================================================
#   3b. WezTerm + WSL bootstrap sanity
# =============================================================================
if (-not $AppsOnly -and -not $ConfigsOnly) {
    Write-Step "WezTerm + WSL bootstrap"
    $weztermCandidates = @(
        "${env:ProgramFiles}\WezTerm\wezterm-gui.exe",
        "$env:LOCALAPPDATA\Programs\WezTerm\wezterm-gui.exe"
    )
    $weztermExe = $weztermCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $weztermExe -and (Get-Command wezterm-gui.exe -ErrorAction SilentlyContinue)) {
        $weztermExe = (Get-Command wezterm-gui.exe).Source
    }
    $wslHelper = Join-Path $WorkstationDir "wezterm\wsl-helper.sh"
    if ($weztermExe) {
        Write-OK "WezTerm installed ($weztermExe)"
    } else {
        Write-Warn "WezTerm executable not found yet (looked in Program Files and LOCALAPPDATA)"
        Write-Warn "  Winget may still be finalizing. Re-run install.ps1 after app installs complete."
    }
    if (Test-Path -LiteralPath $wslHelper) {
        Write-OK "WezTerm helper present: wezterm\wsl-helper.sh"
    } else {
        Write-Warn "Missing wezterm\wsl-helper.sh (WSL right pane will degrade to shell fallback)"
    }

    $wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
    if (-not $wslCmd) {
        Write-Warn "wsl.exe not found — cannot validate distro/bootstrap"
    } else {
        $rawDistroList = (& wsl.exe -l -q 2>$null) -join "`n"
        $distros = $rawDistroList -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        if ($distros.Count -eq 0) {
            if ($DryRun) {
                Write-Skip "Would run: wsl --install -d Ubuntu --no-launch"
            } else {
                try {
                    # "-d Ubuntu" registers the distro as "Ubuntu" — the name wezterm modules/distro.lua expects
                    & wsl.exe --install -d Ubuntu --no-launch
                    if ($LASTEXITCODE -eq 0) {
                        Write-OK "WSL distro bootstrap requested (Ubuntu)"
                    } else {
                        Write-Warn "wsl --install exited $LASTEXITCODE (may require elevation/reboot)"
                    }
                } catch {
                    Write-Warn "WSL distro bootstrap failed — $_"
                }
            }
        } else {
            $preferred = @('Ubuntu', 'Ubuntu-24.04', 'Ubuntu-22.04')
            $chosen = $null
            foreach ($name in $preferred) {
                if ($distros -contains $name) { $chosen = $name; break }
            }
            if (-not $chosen) { $chosen = $distros[0] }

            if ($DryRun) {
                Write-Skip "Would set default WSL distro: $chosen"
            } else {
                try {
                    & wsl.exe --set-default $chosen
                    if ($LASTEXITCODE -eq 0) {
                        Write-OK "WSL default distro set: $chosen"
                    } else {
                        Write-Warn "Could not set WSL default distro (exit $LASTEXITCODE)"
                    }
                } catch {
                    Write-Warn "Could not set WSL default distro — $_"
                }
            }
        }
    }
}

# Python helpers: run even with -NoApps (ConfigsOnly skips everything substantive)
if (-not $ConfigsOnly -and -not $NoPythonProjects) {
    Write-Step "Python venvs (media-organizer, ytdl, transcribe)"
    Install-PythonVenv -VenvDir (Join-Path $WorkstationDir "projects\media-organizer\.venv") `
        -Requirements (Join-Path $WorkstationDir "projects\media-organizer\requirements.txt") `
        -DisplayName "projects\media-organizer" -DryRun:$DryRun
    Install-PythonVenv -VenvDir (Join-Path $WorkstationDir "projects\ytdl\.venv") `
        -Requirements (Join-Path $WorkstationDir "projects\ytdl\requirements.txt") `
        -DisplayName "projects\ytdl" -DryRun:$DryRun
    # Whisper/torch deps — multi-GB download on first install
    Install-PythonVenv -VenvDir "$HOME\workstation\tools\transcribe-env" `
        -Requirements (Join-Path $WorkstationDir "scripts\requirements-transcribe.txt") `
        -DisplayName "tools\transcribe-env (Whisper — large download)" -DryRun:$DryRun
} elseif ($ConfigsOnly) {
    Write-Skip "Skipping Python project venvs (-ConfigsOnly)"
} else {
    Write-Skip "Skipping Python project venvs (-NoPythonProjects)"
}

# =============================================================================
#   4. Windows tweaks (optional — requires admin, skipped if not elevated)
# =============================================================================
if (-not $AppsOnly -and -not $ConfigsOnly) {
    Write-Step "Windows tweaks"
    $tweaksScript = Join-Path $WorkstationDir "windows\tweaks.ps1"
    if (-not (Test-IsAdmin)) {
        Write-Warn "Not running as admin — skipping tweaks. Re-run install.ps1 as admin, or run windows\tweaks.ps1 manually."
    } elseif (Test-Path $tweaksScript) {
        if ($DryRun) {
            Write-Skip "Would run: windows\tweaks.ps1"
        } else {
            & $tweaksScript
            Write-OK "Windows tweaks applied"
        }
    }
}

# =============================================================================
#   5. Symlink configs
# =============================================================================
if (-not $AppsOnly) {
    Write-Step "Linking config files"
    Remove-LegacyWeztermConfig -DryRun:$DryRun
    foreach ($link in (Get-ConfigLinks -WorkstationDir $WorkstationDir)) {
        Sync-ConfigLink -Link $link -WorkstationDir $WorkstationDir -DryRun:$DryRun
    }
}

# =============================================================================
#   6. Editor extensions (VS Code + Cursor share vscode/extensions.txt)
# =============================================================================
if (-not $AppsOnly) {
    $extFile = Join-Path $WorkstationDir "vscode\extensions.txt"

    Write-Step "VS Code extensions"
    Sync-EditorExtensions -DisplayName "VS Code" `
        -CommandCandidates @("$env:ProgramFiles\Microsoft VS Code\bin\code.cmd", "code") `
        -ExtensionsFile $extFile -DryRun:$DryRun

    Write-Step "Cursor extensions"
    Sync-EditorExtensions -DisplayName "Cursor" `
        -CommandCandidates @("$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor.cmd", "cursor") `
        -ExtensionsFile $extFile -DryRun:$DryRun
}

# =============================================================================
#   8. Fonts
# =============================================================================
if (-not $AppsOnly) {
    Write-Step "Fonts"
    Install-NerdFontIfMissing -DryRun:$DryRun
}

# =============================================================================
#   8b. mpv runtime bootstrap (download portable mpv if missing)
# =============================================================================
if (-not $AppsOnly -and -not $ConfigsOnly) {
    Write-Step "mpv runtime bootstrap"
    $mpvDir = Join-Path $HOME "workstation\tools\mpv"
    $mpvExe = Join-Path $mpvDir "mpv.exe"
    $mpvBootstrap = Join-Path $WorkstationDir "mpv-config\install.ps1"
    if (Test-Path -LiteralPath $mpvExe) {
        Write-Skip "mpv runtime already present"
    } elseif (-not (Test-Path -LiteralPath $mpvBootstrap)) {
        Write-Warn "mpv bootstrap script missing: $mpvBootstrap"
    } elseif ($DryRun) {
        Write-Skip "Would bootstrap mpv runtime to $mpvDir via mpv-config\\install.ps1"
    } else {
        try {
            & $mpvBootstrap -InstallDir $mpvDir
            Write-OK "mpv runtime bootstrapped"
        } catch {
            Write-Warn "mpv runtime bootstrap failed — $_"
        }
    }
}

# =============================================================================
#   9. mpv config — junction tools\mpv\portable_config → mpv-config
# =============================================================================
if (-not $AppsOnly -and -not $ConfigsOnly) {
    Write-Step "mpv config"
    $mpvDir          = Join-Path $HOME "workstation\tools\mpv"
    $mpvConfigSrc    = Join-Path $WorkstationDir "mpv-config"
    $portableConfig  = Join-Path $mpvDir "portable_config"
    $mpvConfigSrcFull = [System.IO.Path]::GetFullPath($mpvConfigSrc)

    if (-not (Test-Path -LiteralPath $mpvConfigSrc)) {
        Write-Warn "mpv config bundle missing: $mpvConfigSrc (expected in the repo checkout)"
    } elseif (-not (Test-Path -LiteralPath $mpvDir)) {
        Write-Warn "mpv not found at $mpvDir"
        Write-Warn "  Download shinchiro build and extract to $mpvDir, then re-run install.ps1"
        Write-Warn "  Or run: .\mpv-config\install.ps1 from the repo root"
    } else {
        $alreadyOk = $false
        if (Test-Path -LiteralPath $portableConfig) {
            $item = Get-Item -LiteralPath $portableConfig -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $tgt = $item.Target
                if ($tgt -is [array] -and $tgt.Count -gt 0) { $tgt = $tgt[0] }
                $got = [System.IO.Path]::GetFullPath($tgt.TrimEnd('\', '/'))
                if ($got -ieq $mpvConfigSrcFull) {
                    Write-Skip "mpv portable_config already linked → $mpvConfigSrc"
                    $alreadyOk = $true
                }
            }
        }

        if (-not $alreadyOk) {
            if ($DryRun) {
                if (Test-Path -LiteralPath $portableConfig) {
                    Write-Skip "Would replace $portableConfig with junction → $mpvConfigSrcFull"
                } else {
                    Write-Skip "Would create junction: $portableConfig → $mpvConfigSrcFull"
                }
            } else {
                if (Test-Path -LiteralPath $portableConfig) {
                    $item = Get-Item -LiteralPath $portableConfig -Force
                    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                        Remove-Item -LiteralPath $portableConfig -Force
                    } else {
                        $bak = "$portableConfig.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
                        Move-Item -LiteralPath $portableConfig -Destination $bak
                        Write-Host "   Backed up existing portable_config to $bak" -ForegroundColor DarkGray
                    }
                }
                try {
                    New-Item -ItemType Junction -Path $portableConfig -Target $mpvConfigSrcFull -Force | Out-Null
                    Write-OK "mpv portable_config → mpv-config"
                } catch {
                    Write-Warn "Could not create junction at $portableConfig — $_"
                }
            }
        }
    }
}

# =============================================================================
#   10. mpv — register as "Open with" for video files
# =============================================================================
if (-not $AppsOnly -and -not $ConfigsOnly) {
    Write-Step "mpv Open With registration"
    $batPath = "$HOME\workstation\tools\mpv\mpv-single.bat"
    if (-not (Test-Path $batPath)) {
        Write-Warn "mpv-single.bat not found at $batPath — skipping"
    } elseif ($DryRun) {
        Write-Skip "Would register mpv-single.bat as Open With handler for video files"
    } else {
        $appRegPath = 'HKCU:\Software\Classes\Applications\mpv-single.bat'
        New-Item -Path "$appRegPath\shell\open\command" -Force | Out-Null
        Set-ItemProperty -Path "$appRegPath\shell\open\command" -Name '(Default)' `
            -Value "cmd.exe /c `"`"$batPath`" `"%1`"`"" -Force
        Set-ItemProperty -Path $appRegPath -Name 'FriendlyAppName' -Value 'mpv (single instance)' -Force

        $exts = @('.mkv','.mp4','.avi','.mov','.wmv','.flv','.webm','.m4v','.ts','.m2ts','.mpg','.mpeg')
        foreach ($ext in $exts) {
            New-Item -Path "HKCU:\Software\Classes\$ext\OpenWithList\mpv-single.bat" -Force | Out-Null
        }
        Write-OK "mpv-single.bat registered for $($exts.Count) video extensions"
    }
}

# =============================================================================
#   11. AutoHotkey — register on startup
# =============================================================================
if (-not $AppsOnly) {
    Write-Step "AutoHotkey startup"
    $ahkSrc = Join-Path $WorkstationDir "autohotkey\main.ahk"
    if (Test-Path $ahkSrc) {
        $ahkSrc = (Resolve-Path $ahkSrc).Path
    }
    $ahkExe = Get-AutoHotkeyExe
    if (-not $ahkExe) {
        $ahkExe = "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey64.exe"
    }
    if (Test-Path $ahkSrc) {
        if (-not (Test-Path $ahkExe)) {
            Write-Warn "AutoHotkey.exe not found at $ahkExe — skipping. Install AutoHotkey v2 and re-run."
        } else {
            $runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
            $runVal = "`"$ahkExe`" `"$ahkSrc`""
            $currentRun = (Get-ItemProperty -Path $runKey -Name 'AutoHotkey' -ErrorAction SilentlyContinue).AutoHotkey
            if ($DryRun) {
                if ($currentRun -and $currentRun -ne $runVal) {
                    Write-Skip "Would repair stale AHK Run entry:"
                    Write-Skip "   old: $currentRun"
                }
                Write-Skip "Would register AHK in Run: $runVal"
            } else {
                if ($currentRun -and $currentRun -ne $runVal) {
                    Write-Warn "Repairing stale AHK Run entry:"
                    Write-Warn "   old: $currentRun"
                }
                Set-ItemProperty -Path $runKey -Name 'AutoHotkey' -Value $runVal -Force
                # Launch it now too
                if (Get-Process -Name 'AutoHotkey*' -ErrorAction SilentlyContinue) {
                    Stop-Process -Name 'AutoHotkey*' -Force -ErrorAction SilentlyContinue
                }
                Start-Process -FilePath $ahkExe -ArgumentList "`"$ahkSrc`""
                Write-OK "AutoHotkey registered for startup and launched"
            }
        }
    } else {
        Write-Warn "autohotkey\main.ahk not found — skipping"
    }
}

# =============================================================================
#   WSL provisioning + cron jobs
# =============================================================================
if (-not $ConfigsOnly) {
    Write-Step "WSL provisioning + cron jobs"
    $wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
    $wslScripts = @(
        @{ path = Join-Path $WorkstationDir "wsl\setup.sh";       desc = "WSL provisioning (wsl/setup.sh)" },
        @{ path = Join-Path $WorkstationDir "wsl\setup-crons.sh"; desc = "WSL cron jobs (wsl/setup-crons.sh)" }
    )
    if (-not $wslCmd) {
        Write-Warn "wsl.exe not found — skipping WSL provisioning and cron setup"
    } elseif ($DryRun) {
        Write-Skip "Would run: wsl.exe bash wsl/setup.sh (apt tools, zsh/omz/p10k, shell files, uv, claude/codex/grok/vibe)"
        Write-Skip "Would run: wsl.exe bash wsl/setup-crons.sh (requires sudo inside WSL)"
    } else {
        # A distro registered with --no-launch has no default user yet — the
        # first launch of Ubuntu creates it. Probe before provisioning.
        $probe = (& wsl.exe -e sh -c "echo ready" 2>$null) -join ""
        if ($LASTEXITCODE -ne 0 -or $probe -notmatch 'ready') {
            Write-Warn "WSL distro not initialized yet — launch Ubuntu once to create your user, then re-run install.ps1"
        } else {
            foreach ($s in $wslScripts) {
                if (-not (Test-Path -LiteralPath $s.path)) {
                    Write-Warn "$($s.desc): script not found — skipping"
                    continue
                }
                try {
                    # WSL interop mangles lone backslashes in args — pass forward slashes
                    $winPath = $s.path -replace '\\', '/'
                    $wslPath = (& wsl.exe wslpath -u $winPath 2>$null)
                    if ($wslPath) { $wslPath = ($wslPath -join '').Trim() }
                    if (-not $wslPath) {
                        Write-Warn "$($s.desc): could not translate path via wslpath — skipping"
                        continue
                    }
                    & wsl.exe bash $wslPath
                    if ($LASTEXITCODE -eq 0) {
                        Write-OK $s.desc
                    } else {
                        Write-Warn "$($s.desc) exited $LASTEXITCODE"
                    }
                } catch {
                    Write-Warn "$($s.desc) failed — $_"
                }
            }
        }
    }
}

# =============================================================================
#   Startup hygiene
# =============================================================================
if (-not $ConfigsOnly) {
    Write-Step "Startup cleanup policy"
    Invoke-StartupCleanupPolicy -DryRun:$DryRun
}

# =============================================================================
#   Done
# =============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   All done!" -ForegroundColor Magenta
Write-Host "   Restart your terminal to apply changes." -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""
