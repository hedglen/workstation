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

# Shared helpers (loggers, config map + linker, startup policy, fonts, extensions)
. (Join-Path $DotfilesDir "lib\common.ps1")
. (Join-Path $DotfilesDir "lib\config-links.ps1")
. (Join-Path $DotfilesDir "lib\startup-policy.ps1")
. (Join-Path $DotfilesDir "lib\fonts.ps1")
. (Join-Path $DotfilesDir "lib\extensions.ps1")

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
#   2. Re-link configs (non-destructive -- skips valid existing links/loaders)
# =============================================================================
Write-Step "Config symlinks"

Remove-LegacyWeztermConfig -DryRun:$DryRun
foreach ($link in (Get-ConfigLinks -DotfilesDir $DotfilesDir)) {
    Sync-ConfigLink -Link $link -DotfilesDir $DotfilesDir -DryRun:$DryRun
}

# Workstation-root CLAUDE.md is a copy (workstation\ is not a repo) — flag drift
$claudeMdSrc = Join-Path $DotfilesDir "claude\CLAUDE.md"
$claudeMdDst = Join-Path $HOME "workstation\CLAUDE.md"
if ((Test-Path $claudeMdSrc) -and (Test-Path $claudeMdDst) -and
    ((Get-Content $claudeMdSrc -Raw) -ne (Get-Content $claudeMdDst -Raw))) {
    Write-Warn "workstation\CLAUDE.md differs from dotfiles claude\CLAUDE.md — reconcile and commit"
}

# =============================================================================
#   3. Editor extensions -- install only new ones (VS Code + Cursor)
# =============================================================================
$extFile = Join-Path $DotfilesDir "vscode\extensions.txt"

Write-Step "VS Code extensions"
Sync-EditorExtensions -DisplayName "VS Code" `
    -CommandCandidates @("$env:ProgramFiles\Microsoft VS Code\bin\code.cmd", "code") `
    -ExtensionsFile $extFile -DryRun:$DryRun

Write-Step "Cursor extensions"
Sync-EditorExtensions -DisplayName "Cursor" `
    -CommandCandidates @("$env:LOCALAPPDATA\Programs\cursor\resources\app\bin\cursor.cmd", "cursor") `
    -ExtensionsFile $extFile -DryRun:$DryRun

# =============================================================================
#   4. Fonts -- install if missing
# =============================================================================
Write-Step "Fonts"
Install-NerdFontIfMissing -DryRun:$DryRun

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

    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    foreach ($t in $pythonTargets) {
        if (-not (Test-Path $t.py)) {
            Write-Skip "$($t.name): venv not found (run install.ps1 -NoApps to create)"
            continue
        }
        if ($DryRun) {
            $tool = if ($uvCmd) { 'uv' } else { 'pip' }
            Write-Skip "$($t.name): would $tool install --upgrade $($t.deps -join ' ')"
            continue
        }
        if ($uvCmd) {
            # uv works against any venv (pip-based or uv-created, which has no pip)
            & uv pip install --upgrade --python $t.py @($t.deps) --quiet
        } else {
            & $t.py -m pip install --upgrade pip --quiet 2>&1 | Out-Null
            & $t.py -m pip install --upgrade @($t.deps) --quiet
        }
        if ($LASTEXITCODE -eq 0) {
            Write-OK "$($t.name): dependencies up to date"
        } else {
            Write-Warn "$($t.name): dependency install exited $LASTEXITCODE"
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
