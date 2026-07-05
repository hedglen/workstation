# =============================================================================
#   dotfiles/install.ps1
#   Bootstrap a fresh Windows machine from scratch.
#   https://github.com/hedglen/dotfiles
#
#   Usage:
#     irm https://raw.githubusercontent.com/hedglen/dotfiles/master/install.ps1 | iex
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
$DotfilesDir = $PSScriptRoot
# irm ... | iex has no script path; PSScriptRoot can be empty or whitespace.
$bootstrapFromIex = [string]::IsNullOrWhiteSpace($DotfilesDir)
if ($bootstrapFromIex) {
    $DotfilesDir = "$HOME\workstation\dotfiles"
}

# Shared helpers live in lib\. During an irm|iex bootstrap the repo is not
# cloned yet, so fall back to inline loggers until the local re-invoke.
if (Test-Path (Join-Path $DotfilesDir "lib\common.ps1")) {
    . (Join-Path $DotfilesDir "lib\common.ps1")
    . (Join-Path $DotfilesDir "lib\config-links.ps1")
    . (Join-Path $DotfilesDir "lib\startup-policy.ps1")
    . (Join-Path $DotfilesDir "lib\fonts.ps1")
    . (Join-Path $DotfilesDir "lib\extensions.ps1")
    . (Join-Path $DotfilesDir "lib\python-projects.ps1")
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

function New-WorkspaceFileIfMissing {
    param(
        [Parameter(Mandatory)]
        [string] $WorkspaceRoot,
        [switch] $DryRun
    )
    $wsPath = Join-Path $WorkspaceRoot "rjh-workspace.code-workspace"
    if (Test-Path -LiteralPath $wsPath) {
        Write-Skip "workspace file already present"
        return
    }
    if ($DryRun) {
        Write-Skip "Would create workspace file: $wsPath"
        return
    }
    $wsObject = [ordered]@{
        folders = @(
            @{ name = "hedglen-profile"; path = "hedglen-profile" },
            @{ name = "tools"; path = "tools" },
            @{ name = "dotfiles"; path = "dotfiles" }
        )
        settings = @{
            "files.exclude" = @{
                "**/.git" = $true
                "**/.DS_Store" = $true
                "**/Thumbs.db" = $true
            }
        }
    }
    ($wsObject | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $wsPath -Encoding UTF8
    Write-OK "workspace file created (rjh-workspace.code-workspace)"
}

function Initialize-WorkstationLayout {
    param([switch]$DryRun)
    Write-Step "Workstation layout"
    $wsRoot = Join-Path $HOME "workstation"
    if ($DryRun) {
        Write-Skip "Would create $wsRoot, tools\, and rjh-workspace.code-workspace if missing"
        return
    }
    New-Item -ItemType Directory -Path $wsRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $wsRoot "tools") -Force | Out-Null
    New-WorkspaceFileIfMissing -WorkspaceRoot $wsRoot -DryRun:$false
    Write-OK "workstation root, tools, and workspace file ready"
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
    if (-not (Test-Path -LiteralPath $DotfilesDir)) {
        Write-Host "Cloning dotfiles repo..." -ForegroundColor Cyan
        git clone https://github.com/hedglen/dotfiles.git $DotfilesDir
    }
    & "$DotfilesDir\install.ps1" @PSBoundParameters
    exit
}

Initialize-WorkstationLayout -DryRun:$DryRun
Restart-ElevatedIfNeeded -ScriptPath (Join-Path $DotfilesDir 'install.ps1') -NoElevate:$NoElevate

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   dotfiles installer — hedglen" -ForegroundColor Magenta
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
#   2. Clone workspace repos
# =============================================================================
if (-not $AppsOnly -and -not $ConfigsOnly) {
    Write-Step "Cloning workspace repos"

    $workspaceRepos = @(
        @{ url = "https://github.com/hedglen/hedglen.git";  dst = "$HOME\workstation\hedglen-profile" }
    )

    foreach ($r in $workspaceRepos) {
        $name = Split-Path $r.dst -Leaf
        if (Test-Path $r.dst) {
            Write-Skip "$name already present"
        } elseif ($DryRun) {
            Write-Skip "Would clone $($r.url) → $($r.dst)"
        } else {
            try {
                git clone $r.url $r.dst
                Write-OK "$name cloned"
            } catch {
                Write-Warn "Failed to clone $name — $_"
            }
        }
    }

    # Python helpers (media-organizer, ytdl) ship under dotfiles\projects\
    Write-Step "Projects (dotfiles\projects)"
    $projectsBundled = Join-Path $DotfilesDir "projects"
    if (Test-Path $projectsBundled) {
        Write-OK "projects directory present in dotfiles"
    } elseif ($DryRun) {
        Write-Skip "Would create: $projectsBundled"
    } else {
        New-Item -ItemType Directory -Path $projectsBundled -Force | Out-Null
        Write-Warn "Created empty projects\ — git pull dotfiles for media-organizer / ytdl"
    }

    $legacyProjects = "$HOME\workstation\projects"
    if (Test-Path $legacyProjects) {
        try {
            $item = Get-Item -LiteralPath $legacyProjects -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Write-Skip "workstation\projects already present (junction or symlink)"
            } else {
                Write-Skip "workstation\projects exists as a normal folder — not replaced (merge into dotfiles\projects if needed)"
            }
        } catch {
            Write-Warn "Could not inspect workstation\projects: $_"
        }
    } elseif ($DryRun) {
        Write-Skip "Would create junction: $legacyProjects → $projectsBundled"
    } else {
        try {
            New-Item -ItemType Junction -Path $legacyProjects -Target $projectsBundled | Out-Null
            Write-OK "junction workstation\projects → dotfiles\projects"
        } catch {
            Write-Warn "Could not create junction at $legacyProjects — $_"
        }
    }

    # workstation\, tools\, rjh-workspace.code-workspace are created before elevation (see Initialize-WorkstationLayout).

    # Utility scripts ship inside this repo (not a separate clone).
    Write-Step "Utility scripts (dotfiles\scripts)"
    $scriptsDir = Join-Path $DotfilesDir "scripts"
    if (Test-Path $scriptsDir) {
        Write-OK "scripts directory present"
    } elseif ($DryRun) {
        Write-Skip "Would create: $scriptsDir"
    } else {
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        Write-Warn "Created empty scripts\ — git pull dotfiles for the full script tree"
    }

    # Legacy path: many docs/tools still say $HOME\workstation\scripts
    $legacyScripts = "$HOME\workstation\scripts"
    if (Test-Path $legacyScripts) {
        try {
            $item = Get-Item -LiteralPath $legacyScripts -ErrorAction Stop
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Write-Skip "workstation\scripts already present (junction or symlink)"
            } else {
                Write-Skip "workstation\scripts exists as a normal folder — not replaced (merge into dotfiles\scripts if needed)"
            }
        } catch {
            Write-Warn "Could not inspect workstation\scripts: $_"
        }
    } elseif ($DryRun) {
        Write-Skip "Would create junction: $legacyScripts → $scriptsDir"
    } else {
        try {
            New-Item -ItemType Junction -Path $legacyScripts -Target $scriptsDir | Out-Null
            Write-OK "junction workstation\scripts → dotfiles\scripts"
        } catch {
            Write-Warn "Could not create junction at $legacyScripts — $_"
        }
    }

    # Workstation-root docs — workstation\ itself is not a git repo, so these
    # would be lost on a wipe without a tracked source.
    Write-Step "Workstation root docs"
    $wsRoot      = Join-Path $HOME "workstation"
    $claudeMdSrc = Join-Path $DotfilesDir "claude\CLAUDE.md"
    $claudeMdDst = Join-Path $wsRoot "CLAUDE.md"
    if (-not (Test-Path $claudeMdSrc)) {
        Write-Warn "claude\CLAUDE.md missing from dotfiles — git pull dotfiles"
    } elseif (-not (Test-Path $claudeMdDst)) {
        if ($DryRun) {
            Write-Skip "Would copy claude\CLAUDE.md -> workstation\CLAUDE.md"
        } else {
            Copy-Item $claudeMdSrc $claudeMdDst
            Write-OK "workstation\CLAUDE.md restored from dotfiles"
        }
    } elseif ((Get-Content $claudeMdSrc -Raw) -ne (Get-Content $claudeMdDst -Raw)) {
        Write-Warn "workstation\CLAUDE.md differs from dotfiles claude\CLAUDE.md — reconcile and commit"
    } else {
        Write-Skip "workstation\CLAUDE.md up to date"
    }

    $stubPath = Join-Path $wsRoot "WORKSTATION-SETUP.md"
    if (Test-Path -LiteralPath $stubPath) {
        Write-Skip "WORKSTATION-SETUP.md stub already present"
    } elseif ($DryRun) {
        Write-Skip "Would create WORKSTATION-SETUP.md stub"
    } else {
        @'
# WORKSTATION-SETUP.md (stub)

Canonical guides live in **`dotfiles/docs/`** (tracked with dotfiles).

- **Runbook**: `dotfiles/docs/workstation-setup.md`
- **Layout overview**: `dotfiles/docs/workstation-layout.md`
- **Apps & CLIs**: `dotfiles/apps/winget-packages.json` + `scoop-packages.json` (and the matching `*.md` companions) are the **only** manifests; do not keep copies under `%USERPROFILE%\Documents`. `install.ps1` / `maintenance/update.ps1` read those paths only.
- **Python helpers**: `dotfiles/projects/media-organizer` and `dotfiles/projects/ytdl` (`.venv` from `install.ps1`). `workstation\projects` is a junction to `dotfiles\projects` when the installer could create it.
'@ | Set-Content -LiteralPath $stubPath -Encoding UTF8
        Write-OK "WORKSTATION-SETUP.md stub created"
    }
}

# =============================================================================
#   3. Install apps (single source: this repo only — no %USERPROFILE%\Documents copies)
# =============================================================================
if (-not $ConfigsOnly -and -not $NoApps) {
    Write-Step "Installing apps from winget"

    # Manifest is JSONC (// comments), so it is installed per-ID here rather than
    # via `winget import`, which requires strict schema JSON.
    $pkgFile = Join-Path $DotfilesDir "apps\winget-packages.json"
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

    $scoopFile = Join-Path $DotfilesDir "apps\scoop-packages.json"
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
    $wslHelper = Join-Path $DotfilesDir "wezterm\wsl-helper.sh"
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
    Install-PythonVenv -VenvDir (Join-Path $DotfilesDir "projects\media-organizer\.venv") `
        -Requirements (Join-Path $DotfilesDir "projects\media-organizer\requirements.txt") `
        -DisplayName "projects\media-organizer" -DryRun:$DryRun
    Install-PythonVenv -VenvDir (Join-Path $DotfilesDir "projects\ytdl\.venv") `
        -Requirements (Join-Path $DotfilesDir "projects\ytdl\requirements.txt") `
        -DisplayName "projects\ytdl" -DryRun:$DryRun
    # Whisper/torch deps — multi-GB download on first install
    Install-PythonVenv -VenvDir "$HOME\workstation\tools\transcribe-env" `
        -Requirements (Join-Path $DotfilesDir "scripts\requirements-transcribe.txt") `
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
    $tweaksScript = Join-Path $DotfilesDir "windows\tweaks.ps1"
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
    foreach ($link in (Get-ConfigLinks -DotfilesDir $DotfilesDir)) {
        Sync-ConfigLink -Link $link -DotfilesDir $DotfilesDir -DryRun:$DryRun
    }
}

# =============================================================================
#   6. Editor extensions (VS Code + Cursor share vscode/extensions.txt)
# =============================================================================
if (-not $AppsOnly) {
    $extFile = Join-Path $DotfilesDir "vscode\extensions.txt"

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
    $mpvBootstrap = Join-Path $DotfilesDir "mpv-config\install.ps1"
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
#   9. mpv config — junction tools\mpv\portable_config → dotfiles\mpv-config
# =============================================================================
if (-not $AppsOnly -and -not $ConfigsOnly) {
    Write-Step "mpv config"
    $mpvDir          = Join-Path $HOME "workstation\tools\mpv"
    $mpvConfigSrc    = Join-Path $DotfilesDir "mpv-config"
    $portableConfig  = Join-Path $mpvDir "portable_config"
    $mpvConfigSrcFull = [System.IO.Path]::GetFullPath($mpvConfigSrc)

    if (-not (Test-Path -LiteralPath $mpvConfigSrc)) {
        Write-Warn "mpv config bundle missing: $mpvConfigSrc (expected with dotfiles checkout)"
    } elseif (-not (Test-Path -LiteralPath $mpvDir)) {
        Write-Warn "mpv not found at $mpvDir"
        Write-Warn "  Download shinchiro build and extract to $mpvDir, then re-run install.ps1"
        Write-Warn "  Or run: .\mpv-config\install.ps1 from your dotfiles checkout"
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
                    Write-OK "mpv portable_config → dotfiles\mpv-config"
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
    $ahkSrc = Join-Path $DotfilesDir "autohotkey\main.ahk"
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
        @{ path = Join-Path $DotfilesDir "wsl\setup.sh";       desc = "WSL provisioning (wsl/setup.sh)" },
        @{ path = Join-Path $DotfilesDir "wsl\setup-crons.sh"; desc = "WSL cron jobs (wsl/setup-crons.sh)" }
    )
    if (-not $wslCmd) {
        Write-Warn "wsl.exe not found — skipping WSL provisioning and cron setup"
    } elseif ($DryRun) {
        Write-Skip "Would run: wsl.exe bash wsl/setup.sh (apt tools, zsh/omz/p10k, shell files, uv, claude/codex/grok)"
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
                    $wslPath = (& wsl.exe wslpath -u $s.path).Trim()
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
