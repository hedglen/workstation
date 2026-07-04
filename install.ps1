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

function Write-Step { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$Msg) Write-Host "   OK  $Msg" -ForegroundColor Green }
function Write-Skip { param([string]$Msg) Write-Host "   --  $Msg" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Msg) Write-Host "   !!  $Msg" -ForegroundColor Yellow }

function Invoke-StartupCleanupPolicy {
    param([switch]$DryRun)

    $runPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $runValues = @(
        'AdobeBridge',
        'Adobe Acrobat Synchronizer',
        'GoogleChromeAutoLaunch_2B79721E5FCF3159A6E77C5981E57BF6',
        'Discord',
        'org.whispersystems.signal-desktop',
        'WingetUI',
        'IDMan',
        'LGHUB'
    )
    $startupShortcut = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\Send to OneNote.lnk'

    foreach ($name in $runValues) {
        $exists = [bool](Get-ItemProperty -Path $runPath -Name $name -ErrorAction SilentlyContinue)
        if (-not $exists) {
            Write-Skip "Startup cleanup: $name not present"
            continue
        }
        if ($DryRun) {
            Write-Skip "Startup cleanup: would remove HKCU Run '$name'"
            continue
        }
        try {
            Remove-ItemProperty -Path $runPath -Name $name -ErrorAction Stop
            Write-OK "Startup cleanup: removed HKCU Run '$name'"
        } catch {
            Write-Warn "Startup cleanup: failed to remove '$name' — $_"
        }
    }

    if (-not (Test-Path -LiteralPath $startupShortcut)) {
        Write-Skip "Startup cleanup: Send to OneNote startup shortcut not present"
    } elseif ($DryRun) {
        Write-Skip "Startup cleanup: would remove Send to OneNote startup shortcut"
    } else {
        try {
            Remove-Item -LiteralPath $startupShortcut -Force -ErrorAction Stop
            Write-OK "Startup cleanup: removed Send to OneNote startup shortcut"
        } catch {
            Write-Warn "Startup cleanup: failed to remove Send to OneNote startup shortcut — $_"
        }
    }
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
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) { return }

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

function Install-DotfilesPythonProject {
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath,
        [Parameter(Mandatory)]
        [string[]] $PipArgs,
        [switch] $DryRun
    )
    $proj = Join-Path $DotfilesDir $RelativePath
    if (-not (Test-Path $proj)) {
        Write-Warn "Project not found — $RelativePath"
        return
    }
    # uv is much faster and manifest-managed (astral-sh.uv); fall back to py + pip.
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    $py = Get-Command py -ErrorAction SilentlyContinue
    if (-not $uv -and -not $py) {
        Write-Warn "Neither uv nor the Python launcher (py) is on PATH — skip venv for $RelativePath"
        return
    }
    $venvPy = Join-Path $proj ".venv\Scripts\python.exe"
    if ($DryRun) {
        $tool = if ($uv) { "uv" } else { "pip" }
        if (Test-Path $venvPy) {
            Write-Skip "Would $tool install in $RelativePath (venv exists)"
        } else {
            Write-Skip "Would create .venv ($tool) and install deps in $RelativePath"
        }
        return
    }
    Push-Location $proj
    try {
        if (-not (Test-Path $venvPy)) {
            if ($uv) { & uv venv .venv } else { & py -3 -m venv .venv }
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "venv creation failed in $RelativePath"
                return
            }
        }
        $prevEA = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        if ($uv) {
            & uv pip install --python $venvPy @PipArgs
        } else {
            # uv-created venvs have no pip; python -m pip only works on stdlib venvs
            & $venvPy -m pip install --upgrade pip 2>$null | Out-Null
            & $venvPy -m pip install @PipArgs
        }
        $exit = $LASTEXITCODE
        $ErrorActionPreference = $prevEA
        if ($exit -eq 0) {
            Write-OK "Python venv: $RelativePath"
        } else {
            Write-Warn "dependency install exited $exit for $RelativePath"
        }
    } finally {
        Pop-Location
    }
}

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
}

# =============================================================================
#   3b. WezTerm + WSL bootstrap sanity
# =============================================================================
if (-not $AppsOnly -and -not $ConfigsOnly) {
    Write-Step "WezTerm + WSL bootstrap"
    $weztermExe = "$env:LOCALAPPDATA\Programs\WezTerm\wezterm-gui.exe"
    $wslHelper = Join-Path $DotfilesDir "wezterm\wsl-helper.sh"
    if (Test-Path -LiteralPath $weztermExe) {
        Write-OK "WezTerm installed"
    } else {
        Write-Warn "WezTerm executable not found yet ($weztermExe)"
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
    Write-Step "Python venvs (media-organizer, ytdl)"
    Install-DotfilesPythonProject -RelativePath "projects\media-organizer" -PipArgs @("-r", "requirements.txt") -DryRun:$DryRun
    Install-DotfilesPythonProject -RelativePath "projects\ytdl" -PipArgs @("-r", "requirements.txt") -DryRun:$DryRun
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
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
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

    $configs = @(
        @{
            src    = "powershell\profile.ps1"
            dst    = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
            desc   = "PowerShell profile"
            # Materialize as a real loader file, NOT a symlink. Windows' Redirection
            # Trust mitigation blocks dot-sourcing a symlinked profile with
            # "untrusted mount point", which stops the profile from loading.
            loader = $true
        },
        @{
            src  = "git\.gitconfig"
            dst  = "$HOME\.gitconfig"
            desc = "Git config"
        },
        @{
            src  = "windows-terminal\settings.json"
            dst  = "$HOME\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
            desc = "Windows Terminal"
        },
        @{
            src  = "vscode\settings.json"
            dst  = "$HOME\AppData\Roaming\Code\User\settings.json"
            desc = "VS Code settings"
        },
        @{
            src  = "vscode\settings.json"
            dst  = "$HOME\AppData\Roaming\Cursor\User\settings.json"
            desc = "Cursor settings"
        },
        @{
            src  = "projects\ytdl\appdata-config"
            dst  = "$env:APPDATA\yt-dlp\config"
            desc = "yt-dlp global config (from projects/ytdl)"
        },
        @{
            src  = "wezterm"
            dst  = "$HOME\.config\wezterm"
            desc = "WezTerm"
        }
    )

    foreach ($c in $configs) {
        $src    = Join-Path $DotfilesDir $c.src
        $dst    = $c.dst
        $dstDir = Split-Path $dst -Parent

        if (-not (Test-Path $src)) {
            Write-Warn "$($c.desc): source not found ($src)"
            continue
        }

        if ($DryRun) {
            Write-Skip "$($c.desc): $src -> $dst"
            continue
        }

        # Loader stub: write a REAL file that dot-sources the canonical profile.
        # A symlink here triggers Windows' Redirection Trust mitigation
        # ("untrusted mount point"), which prevents the profile from loading.
        if ($c.loader) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
            $loaderLine = ". `"$src`""
            $existingLoader = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
            if ($existingLoader -and ($existingLoader.LinkType -eq 'SymbolicLink' -or $existingLoader.LinkType -eq 'Junction')) {
                Remove-Item -LiteralPath $dst -Force
            } elseif ($existingLoader -and ((Get-Content -LiteralPath $dst -Raw -ErrorAction SilentlyContinue).Trim() -eq $loaderLine)) {
                Write-Skip "$($c.desc) loader already in place"
                continue
            }
            Set-Content -LiteralPath $dst -Value $loaderLine -Encoding utf8
            Write-OK "$($c.desc) (loader stub — avoids untrusted mount point)"
            continue
        }

        if ($c.desc -eq "WezTerm" -and -not $DryRun) {
            $oldWeztermLink = "$HOME\.wezterm.lua"
            if (Test-Path -LiteralPath $oldWeztermLink -ErrorAction SilentlyContinue) {
                Remove-Item -LiteralPath $oldWeztermLink -Force -ErrorAction SilentlyContinue
                Write-OK "WezTerm legacy ~/.wezterm.lua removed"
            }
        }

        # Skip if symlink already points to the right place (full paths; Target may be string[])
        if (Test-Path -LiteralPath $dst -ErrorAction SilentlyContinue) {
            $linkItem = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
            if ($linkItem -and ($linkItem.LinkType -eq 'SymbolicLink' -or $linkItem.LinkType -eq 'Junction')) {
                $t = $linkItem.Target
                if ($t -is [System.Array]) { $t = $t[0] }
                try {
                    if ([IO.Path]::GetFullPath($t) -eq [IO.Path]::GetFullPath($src)) {
                        Write-Skip "$($c.desc) already linked"
                        continue
                    }
                } catch { }
            }
        }

        # Ensure destination directory exists (-Force is idempotent; creates full path)
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null

        # Wrong symlink: remove (Copy-Item on links often fails). Plain file/dir: back up then remove.
        $existing = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
        if ($existing) {
            if ($existing.LinkType -eq 'SymbolicLink' -or $existing.LinkType -eq 'Junction') {
                Remove-Item -LiteralPath $dst -Force
            } elseif ($existing.PSIsContainer) {
                $backup = "$dst.backup"
                Copy-Item -LiteralPath $dst -Destination $backup -Recurse -Force
                Remove-Item -LiteralPath $dst -Recurse -Force
                Write-Host "   Backed up existing to $backup" -ForegroundColor DarkGray
            } else {
                $backup = "$dst.backup"
                Copy-Item -LiteralPath $dst -Destination $backup -Force
                Remove-Item -LiteralPath $dst -Force
                Write-Host "   Backed up existing to $backup" -ForegroundColor DarkGray
            }
        }

        # Try junction for WezTerm directory, symlink otherwise; fall back to copy
        try {
            $linkType = if ($c.desc -eq "WezTerm") { "Junction" } else { "SymbolicLink" }
            New-Item -ItemType $linkType -Path $dst -Target $src -Force | Out-Null
            Write-OK "$($c.desc) (symlinked)"
        } catch {
            if (Test-Path -LiteralPath $src -PathType Container) {
                Copy-Item $src $dst -Recurse -Force
            } else {
                Copy-Item $src $dst -Force
            }
            Write-Warn "$($c.desc) (copied — run as admin for symlinks)"
        }
    }
}

# =============================================================================
#   6. VS Code extensions
# =============================================================================
if (-not $AppsOnly) {
    Write-Step "VS Code extensions"
    $codeCmd = "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
    if (-not (Test-Path $codeCmd)) { $codeCmd = "code" }
    if (Get-Command $codeCmd -ErrorAction SilentlyContinue) {
        $extFile = Join-Path $DotfilesDir "vscode\extensions.txt"
        if (Test-Path $extFile) {
            Get-Content $extFile |
            Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^\s*#' } |
            ForEach-Object {
                $ext = $_.Trim()
                if ($DryRun) {
                    Write-Skip "Would install: $ext"
                } else {
                    $installOut = & $codeCmd --install-extension $ext --force 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warn "Failed to install extension: $ext"
                        $installOut | ForEach-Object { Write-Warn "  $_" }
                    } else {
                        Write-OK $ext
                    }
                }
            }
        }
    } else {
        Write-Warn "VS Code (code) not on PATH -- skipping extensions"
    }
}

# =============================================================================
#   7. Cursor extensions
# =============================================================================
if (-not $AppsOnly) {
    Write-Step "Cursor extensions"
    $cursorCmd = "$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor.cmd"
    if (-not (Test-Path $cursorCmd)) { $cursorCmd = "cursor" }
    if (Get-Command $cursorCmd -ErrorAction SilentlyContinue) {
        $extFile = Join-Path $DotfilesDir "vscode\extensions.txt"
        if (Test-Path $extFile) {
            Get-Content $extFile |
            Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^\s*#' } |
            ForEach-Object {
                $ext = $_.Trim()
                if ($DryRun) {
                    Write-Skip "Would install: $ext"
                } else {
                    $installOut = & $cursorCmd --install-extension $ext --force 2>&1
                    if ($LASTEXITCODE -ne 0) {
                        Write-Warn "Failed to install extension: $ext"
                        $installOut | ForEach-Object { Write-Warn "  $_" }
                    } else {
                        Write-OK $ext
                    }
                }
            }
        }
    } else {
        Write-Warn "Cursor not on PATH — skipping extensions"
    }
}

# =============================================================================
#   8. Fonts
# =============================================================================
if (-not $AppsOnly) {
    Write-Step "Fonts"

    $fontsDir  = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $regPath   = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $checkFont = 'CaskaydiaCove Nerd Font Regular (TrueType)'

    $installed = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).$checkFont
    if (-not $installed) {
        $installed = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue).$checkFont
    }
    if (-not $installed) {
        $fontFile = Get-ChildItem "$fontsDir\CaskaydiaCove*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($fontFile) { $installed = $fontFile.FullName }
    }

    if ($installed) {
        Write-Skip "CaskaydiaCove Nerd Font already installed"
    } elseif ($DryRun) {
        Write-Skip "Would download and install CaskaydiaCove Nerd Font"
    } else {
        $tmpZip    = "$env:TEMP\CascadiaCode.zip"
        $tmpExtract = "$env:TEMP\CascadiaCode-nf"
        $fontUrl   = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"

        Write-Host "   Downloading CaskaydiaCove Nerd Font..." -ForegroundColor DarkGray
        Invoke-WebRequest -Uri $fontUrl -OutFile $tmpZip -UseBasicParsing

        Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force

        if (-not (Test-Path $fontsDir)) { New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null }

        $count = 0
        Get-ChildItem $tmpExtract -Filter "*.ttf" | ForEach-Object {
            $dst = Join-Path $fontsDir $_.Name
            Copy-Item $_.FullName $dst -Force
            $fontName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + " (TrueType)"
            Set-ItemProperty -Path $regPath -Name $fontName -Value $dst -Force
            $count++
        }

        Remove-Item $tmpZip, $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "Installed $count font files to $fontsDir"
    }
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
    # Prefer a real AutoHotkey64.exe. WindowsApps\AutoHotkey.exe is an app-alias shim that runs
    # launcher.ahk and often throws "cannot find path" on FileRead(ScriptPath) at startup.
    $ahkCandidates = @(
        "${env:ProgramFiles}\AutoHotkey\v2\AutoHotkey64.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\AutoHotkey64.exe"
    )
    $ahkExe = $ahkCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    if (-not $ahkExe) {
        $ahkCmd = Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue
        if ($ahkCmd -and $ahkCmd.Source -notmatch '\\WindowsApps\\') {
            $ahkExe = $ahkCmd.Source
        }
    }
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
#   WSL cron jobs
# =============================================================================
if (-not $ConfigsOnly) {
    Write-Step "WSL cron jobs"
    $wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
    $cronSetup = Join-Path $DotfilesDir "wsl\setup-crons.sh"
    if (-not $wslCmd) {
        Write-Warn "wsl.exe not found — skipping WSL cron setup"
    } elseif (-not (Test-Path -LiteralPath $cronSetup)) {
        Write-Warn "wsl\setup-crons.sh not found — skipping"
    } elseif ($DryRun) {
        Write-Skip "Would run: wsl.exe bash wsl/setup-crons.sh (requires sudo inside WSL)"
    } else {
        try {
            $wslPath = (& wsl.exe wslpath -u $cronSetup).Trim()
            & wsl.exe bash $wslPath
            if ($LASTEXITCODE -eq 0) {
                Write-OK "WSL cron jobs installed"
            } else {
                Write-Warn "WSL cron setup exited $LASTEXITCODE"
            }
        } catch {
            Write-Warn "WSL cron setup failed — $_"
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
