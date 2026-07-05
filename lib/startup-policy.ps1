# =============================================================================
#   dotfiles/lib/startup-policy.ps1
#   Startup hygiene: remove HKCU Run entries and shortcuts that apps re-add.
#   Requires lib/common.ps1. Dot-source; do not run directly.
# =============================================================================

function Invoke-StartupCleanupPolicy {
    param([switch]$DryRun)

    $runPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    $runValues = @(
        'AdobeBridge',
        'Adobe Acrobat Synchronizer',
        'Discord',
        'org.whispersystems.signal-desktop',
        'WingetUI',
        'IDMan',
        'LGHUB'
    )
    # Chrome appends a machine-specific hash to its Run value name
    $runPatterns = @('GoogleChromeAutoLaunch_*')
    $startupShortcut = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\Send to OneNote.lnk'

    $runKey = Get-Item -Path $runPath -ErrorAction SilentlyContinue
    $allNames = if ($runKey) { @($runKey.Property) } else { @() }

    $targets = @()
    foreach ($name in $runValues) {
        if ($allNames -contains $name) {
            $targets += $name
        } else {
            Write-Skip "Startup cleanup: $name not present"
        }
    }
    foreach ($pattern in $runPatterns) {
        $hits = @($allNames | Where-Object { $_ -like $pattern })
        if ($hits) {
            $targets += $hits
        } else {
            Write-Skip "Startup cleanup: $pattern not present"
        }
    }

    foreach ($name in $targets) {
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
