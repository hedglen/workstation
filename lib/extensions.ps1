# =============================================================================
#   dotfiles/lib/extensions.ps1
#   Editor extension sync from vscode/extensions.txt (VS Code and Cursor share
#   the list). Installs only what is missing.
#   Requires lib/common.ps1. Dot-source; do not run directly.
# =============================================================================

function Sync-EditorExtensions {
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        # Full paths tried first, bare command name last (PATH lookup)
        [Parameter(Mandatory)][string[]]$CommandCandidates,
        [Parameter(Mandatory)][string]$ExtensionsFile,
        [switch]$DryRun
    )

    $cli = $null
    foreach ($cand in $CommandCandidates) {
        if ((Test-Path -LiteralPath $cand -ErrorAction SilentlyContinue) -or
            (Get-Command $cand -ErrorAction SilentlyContinue)) {
            $cli = $cand
            break
        }
    }
    if (-not $cli) {
        Write-Warn "$DisplayName not on PATH — skipping extensions"
        return
    }
    if (-not (Test-Path $ExtensionsFile)) {
        Write-Warn "Extensions file not found: $ExtensionsFile"
        return
    }

    $wanted = Get-Content $ExtensionsFile |
        Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^\s*#' } |
        ForEach-Object { $_.Trim() }
    $installed = @(& $cli --list-extensions 2>$null | ForEach-Object { $_.ToLower() })
    $toInstall = @($wanted | Where-Object { $installed -notcontains $_.ToLower() })

    if (-not $toInstall) {
        Write-Skip "${DisplayName}: all extensions already installed"
        return
    }

    foreach ($ext in $toInstall) {
        if ($DryRun) {
            Write-Skip "${DisplayName}: would install $ext"
            continue
        }
        $installOut = & $cli --install-extension $ext --force 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "${DisplayName}: failed to install extension $ext"
            $installOut | ForEach-Object { Write-Warn "  $_" }
        } else {
            Write-OK "${DisplayName}: $ext"
        }
    }
}
