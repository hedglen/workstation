# =============================================================================
#   dotfiles/maintenance/update.ps1
#   Keep a running machine in sync with your dotfiles repo.
#
#   Usage:
#     .\maintenance\update.ps1             # full update
#     .\maintenance\update.ps1 -SkipApps   # pull + relink + extensions, no winget/scoop upgrades
#     .\maintenance\update.ps1 -SkipDots   # upgrade apps only, skip git pull
#     .\maintenance\update.ps1 -SkipPython # skip Python venv dependency updates
#     .\maintenance\update.ps1 -DryRun     # preview without making changes
#
#   Tip: use `dots-update` (alias `update-all`) from your PowerShell profile.
# =============================================================================

param(
    [switch]$SkipApps,
    [switch]$SkipDots,
    [switch]$SkipPython,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$DotfilesDir = Split-Path $PSScriptRoot -Parent

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

function Test-WingetPackageInstalled {
    param([Parameter(Mandatory)][string]$Id)
    try {
        $out = (& winget list --id $Id -e --accept-source-agreements 2>$null) -join "`n"
        return ($out -match [regex]::Escape($Id))
    } catch {
        return $false
    }
}

function Invoke-WingetSafe {
    param(
        [Parameter(Mandatory)][string]$PackageId,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$Verb = "winget"
    )
    try {
        $output = (& winget @Arguments 2>&1)
        return [PSCustomObject]@{
            Success  = ($LASTEXITCODE -eq 0)
            ExitCode = $LASTEXITCODE
            Output   = @($output)
            Threw    = $false
            Error    = $null
            Verb     = $Verb
            Id       = $PackageId
        }
    } catch {
        return [PSCustomObject]@{
            Success  = $false
            ExitCode = $LASTEXITCODE
            Output   = @()
            Threw    = $true
            Error    = $_
            Verb     = $Verb
            Id       = $PackageId
        }
    }
}

$WingetUpdateNotApplicableExitCode = -1978335189

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   dotfiles updater -- hedglen" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta
if ($DryRun) { Write-Host "   DRY RUN -- no changes will be made" -ForegroundColor Yellow }
Write-Host ""

# =============================================================================
#   1. Pull dotfiles
# =============================================================================
if (-not $SkipDots) {
    Write-Step "Pulling dotfiles from GitHub"
    Push-Location $DotfilesDir

    $dirty = git status --porcelain
    if ($dirty) {
        Write-Warn "Uncommitted changes detected -- skipping pull to avoid conflicts."
        Write-Warn "Run 'save-dots' first, or stash your changes manually."
    } elseif ($DryRun) {
        Write-Skip "Would run: git pull"
    } else {
        git pull
        Write-OK "Dotfiles up to date"
    }

    Pop-Location
}

Write-Step "WezTerm helper scripts"
$wslHelper = Join-Path $DotfilesDir "wezterm\wsl-helper.sh"
if (Test-Path -LiteralPath $wslHelper) {
    Write-OK "wezterm\wsl-helper.sh present"
} else {
    Write-Warn "Missing wezterm\wsl-helper.sh (WSL right pane will degrade to shell fallback)"
}

# =============================================================================
#   2. Re-link configs (non-destructive -- skips valid existing symlinks)
# =============================================================================
Write-Step "Config symlinks"

$configs = @(
    @{
        src  = "powershell\profile.ps1"
        dst  = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        desc = "PowerShell profile"
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
        desc = "WezTerm (directory)"
    }
)

foreach ($c in $configs) {
    $src = Join-Path $DotfilesDir $c.src
    $dst = $c.dst

    if (-not (Test-Path $src)) {
        Write-Warn "$($c.desc): source not found ($src)"
        continue
    }

    # Check if link already points to the right place (full paths; Target may be string[])
    if (Test-Path -LiteralPath $dst -ErrorAction SilentlyContinue) {
        $item = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType -in 'SymbolicLink', 'Junction') {
            $t = $item.Target
            if ($t -is [System.Array]) { $t = $t[0] }
            try {
                if ([IO.Path]::GetFullPath($t) -eq [IO.Path]::GetFullPath($src)) {
                    Write-Skip "$($c.desc): already linked"
                    continue
                }
            } catch { }
        }
    }

    if ($DryRun) {
        Write-Skip "$($c.desc): would link $src -> $dst"
        continue
    }

    $dstDir = Split-Path $dst -Parent
    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null

    $existing = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.LinkType -in 'SymbolicLink', 'Junction') {
            Remove-Item -LiteralPath $dst -Force
        } elseif ($existing.PSIsContainer) {
            Copy-Item -LiteralPath $dst -Destination "$dst.backup" -Recurse -Force
            Remove-Item -LiteralPath $dst -Recurse -Force
            Write-Host "   Backed up existing to $dst.backup" -ForegroundColor DarkGray
        } else {
            Copy-Item -LiteralPath $dst -Destination "$dst.backup" -Force
            Remove-Item -LiteralPath $dst -Force
            Write-Host "   Backed up existing to $dst.backup" -ForegroundColor DarkGray
        }
    }

    try {
        # Junction for directories (no admin needed), symlink for files
        $linkType = if ((Get-Item -LiteralPath $src).PSIsContainer) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkType -Path $dst -Target $src -Force | Out-Null
        Write-OK "$($c.desc) ($($linkType.ToLower()))"
    } catch {
        Copy-Item $src $dst -Force -Recurse
        Write-Warn "$($c.desc) (copied -- run as admin for symlinks)"
    }
}

# Legacy WezTerm config file superseded by the ~/.config/wezterm directory junction
$legacyWezterm = "$HOME\.wezterm.lua"
if (Test-Path -LiteralPath $legacyWezterm) {
    if ($DryRun) {
        Write-Skip "Would remove legacy ~/.wezterm.lua (config lives in ~/.config/wezterm)"
    } else {
        Remove-Item -LiteralPath $legacyWezterm -Force -ErrorAction SilentlyContinue
        Write-OK "Removed legacy ~/.wezterm.lua"
    }
}

# =============================================================================
#   3. VS Code extensions -- install only new ones
# =============================================================================
Write-Step "VS Code extensions"

$codeCmd = "$env:ProgramFiles\Microsoft VS Code\bin\code.cmd"
if (-not (Test-Path $codeCmd)) { $codeCmd = "code" }
if (Get-Command $codeCmd -ErrorAction SilentlyContinue) {
    $extFile = Join-Path $DotfilesDir "vscode\extensions.txt"
    if (Test-Path $extFile) {
        $installed = & $codeCmd --list-extensions 2>$null | ForEach-Object { $_.ToLower() }
        $wanted = Get-Content $extFile |
            Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^\s*#' } |
            ForEach-Object { $_.Trim() }

        $toInstall = $wanted | Where-Object { $installed -notcontains $_.ToLower() }

        if (-not $toInstall) {
            Write-Skip "All extensions already installed"
        } else {
            foreach ($ext in $toInstall) {
                if ($DryRun) {
                    Write-Skip "Would install: $ext"
                } else {
                    & $codeCmd --install-extension $ext --force 2>&1 | Out-Null
                    Write-OK $ext
                }
            }
        }
    }
} else {
    Write-Warn "VS Code (code) not on PATH -- skipping"
}

# =============================================================================
#   4. Fonts -- install if missing
# =============================================================================
Write-Step "Fonts"

$fontsDir  = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$regPath   = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$checkFont = 'CaskaydiaCove Nerd Font Regular (TrueType)'

# Check HKCU first, then HKLM (system-wide install), then fallback to file presence
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
    $tmpZip     = "$env:TEMP\CascadiaCode.zip"
    $tmpExtract = "$env:TEMP\CascadiaCode-nf"
    $fontUrl    = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"

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
    Write-OK "Installed $count font files"
}

# =============================================================================
#   5. Upgrade apps via winget (managed packages only)
# =============================================================================
if (-not $SkipApps) {
    Write-Step "Upgrading apps (winget)"

    $pkgFile = Join-Path $DotfilesDir "apps\winget-packages.json"
    if (-not (Test-Path $pkgFile)) {
        Write-Warn "apps\winget-packages.json not found -- skipping"
    } else {
        $packages = @((Get-Content $pkgFile -Raw | ConvertFrom-Json).packages | Where-Object { $_ })
        $wingetFailures = New-Object System.Collections.Generic.List[string]

        foreach ($id in $packages) {
            if ($DryRun) {
                Write-Skip "Would ensure installed + upgrade: $id"
            } else {
                $isInstalled = Test-WingetPackageInstalled -Id $id
                if (-not $isInstalled) {
                    $installResult = Invoke-WingetSafe -PackageId $id -Verb "install" -Arguments @(
                        "install", "--id", $id, "-e", "--accept-package-agreements", "--accept-source-agreements"
                    )
                    if ($installResult.Success) {
                        Write-OK "$id (installed)"
                    } else {
                        Write-Warn "$id install failed (exit $($installResult.ExitCode))"
                        if ($installResult.Threw) {
                            Write-Warn "  $($installResult.Error)"
                        } else {
                            $installResult.Output | ForEach-Object { Write-Warn "  $_" }
                        }
                        $wingetFailures.Add("$id (install)")
                        continue
                    }
                }

                $upgradeResult = Invoke-WingetSafe -PackageId $id -Verb "upgrade" -Arguments @(
                    "upgrade", "--id", $id, "-e", "--accept-package-agreements", "--accept-source-agreements"
                )
                $upgradeText = ($upgradeResult.Output -join "`n")
                if (
                    ($upgradeResult.ExitCode -eq $WingetUpdateNotApplicableExitCode) -or
                    ($upgradeText -match 'No applicable upgrade') -or
                    ($upgradeText -match 'No available upgrade found') -or
                    ($upgradeText -match 'No newer package versions are available')
                ) {
                    Write-Skip "$id (up to date)"
                } elseif ($upgradeResult.Success) {
                    Write-OK "$id"
                } else {
                    Write-Warn "$id upgrade failed (exit $($upgradeResult.ExitCode))"
                    if ($upgradeResult.Threw) {
                        Write-Warn "  $($upgradeResult.Error)"
                    } else {
                        $upgradeResult.Output | Select-Object -First 3 | ForEach-Object { Write-Warn "  $_" }
                    }
                    $wingetFailures.Add("$id (upgrade)")
                }
            }
        }

        if (-not $DryRun -and $wingetFailures.Count -gt 0) {
            Write-Warn ("Winget had {0} package failure(s): {1}" -f $wingetFailures.Count, ($wingetFailures -join ', '))
            Write-Warn "Updater continued; re-run a failed package manually with: winget upgrade --id <PackageId>"
        }
    }

    Write-Step "Updating Scoop apps (if Scoop is available)"

    $scoopFile = Join-Path $DotfilesDir "apps\scoop-packages.json"
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Warn "Scoop not on PATH — skipping"
    } elseif (-not (Test-Path $scoopFile)) {
        Write-Warn "apps\scoop-packages.json not found — skipping Scoop"
    } elseif ($DryRun) {
        Write-Skip "Would install missing packages from apps\\scoop-packages.json"
        Write-Skip "Would run: scoop update *"
    } else {
        $names = @((Get-Content $scoopFile -Raw | ConvertFrom-Json).packages | Where-Object { $_ })
        if ($names.Count -eq 0) {
            Write-Skip "No package names in scoop-packages.json"
        } else {
            $installedSet = @{}
            try {
                & scoop list 2>$null | ForEach-Object {
                    $line = $_.ToString().Trim()
                    if ($line -and $line -notmatch '^Name\s+Version\s+Source' -and $line -notmatch '^----') {
                        $pkg = ($line -split '\s+')[0]
                        if ($pkg) { $installedSet[$pkg.ToLower()] = $true }
                    }
                }
            } catch { }

            $missing = @($names | Where-Object { -not $installedSet.ContainsKey($_.ToLower()) })
            if ($missing.Count -gt 0) {
                & scoop install @missing
                if ($LASTEXITCODE -eq 0) {
                    Write-OK "scoop install ($($missing.Count) missing)"
                } else {
                    Write-Warn "scoop install exited $LASTEXITCODE"
                }
            } else {
                Write-Skip "All Scoop manifest packages already installed"
            }
        }

        cmd /c "scoop update *"
        if ($LASTEXITCODE -eq 0) {
            Write-OK "scoop update *"
        } else {
            Write-Warn "scoop update exited $LASTEXITCODE"
        }
    }
}

# =============================================================================
#   6. Python venvs -- upgrade pip + project dependencies
# =============================================================================
if (-not $SkipPython) {
    Write-Step "Updating Python venv dependencies"

    $pythonTargets = @(
        @{
            name = "media-organizer"
            py   = Join-Path $DotfilesDir "projects\media-organizer\.venv\Scripts\python.exe"
            deps = @("-r", (Join-Path $DotfilesDir "projects\media-organizer\requirements.txt"))
        },
        @{
            name = "ytdl"
            py   = Join-Path $DotfilesDir "projects\ytdl\.venv\Scripts\python.exe"
            deps = @("-r", (Join-Path $DotfilesDir "projects\ytdl\requirements.txt"))
        },
        @{
            name = "transcribe-env"
            py   = "$HOME\workstation\tools\transcribe-env\Scripts\python.exe"
            deps = @("-r", (Join-Path $DotfilesDir "scripts\requirements-transcribe.txt"))
        }
    )

    foreach ($t in $pythonTargets) {
        if (-not (Test-Path $t.py)) {
            Write-Skip "$($t.name): venv not found (run install.ps1 -NoApps to create)"
            continue
        }
        if ($DryRun) {
            Write-Skip "$($t.name): would upgrade pip + $($t.deps -join ' ')"
            continue
        }
        & $t.py -m pip install --upgrade pip --quiet 2>&1 | Out-Null
        & $t.py -m pip install --upgrade @($t.deps) --quiet
        if ($LASTEXITCODE -eq 0) {
            Write-OK "$($t.name): dependencies up to date"
        } else {
            Write-Warn "$($t.name): pip exited $LASTEXITCODE"
        }
    }
}

Write-Step "Startup cleanup policy"
Invoke-StartupCleanupPolicy -DryRun:$DryRun

# =============================================================================
#   Done
# =============================================================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host "   All done!" -ForegroundColor Magenta
if (-not $SkipApps -and -not $DryRun) {
    Write-Host "   Restart your terminal if the profile changed." -ForegroundColor Magenta
}
Write-Host "============================================" -ForegroundColor Magenta
Write-Host ""
