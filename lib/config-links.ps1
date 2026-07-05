# =============================================================================
#   dotfiles/lib/config-links.ps1
#   Single source of truth for which configs get linked where, plus the linker.
#   Consumed by install.ps1, maintenance/update.ps1 (via Sync-ConfigLink) and
#   scripts/workstation-health.ps1 (map only, for spot-checks).
#   Requires lib/common.ps1 (Write-OK/Skip/Warn). Dot-source; do not run directly.
# =============================================================================

function Get-ConfigLinks {
    param([Parameter(Mandatory)][string]$DotfilesDir)
    @(
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
            src  = "claude\settings.json"
            dst  = "$HOME\.claude\settings.json"
            desc = "Claude Code settings"
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
}

function Sync-ConfigLink {
    param(
        [Parameter(Mandatory)][hashtable]$Link,
        [Parameter(Mandatory)][string]$DotfilesDir,
        [switch]$DryRun
    )

    $src    = Join-Path $DotfilesDir $Link.src
    $dst    = $Link.dst
    $desc   = $Link.desc
    $dstDir = Split-Path $dst -Parent

    if (-not (Test-Path $src)) {
        Write-Warn "${desc}: source not found ($src)"
        return
    }

    # Loader stub: write a REAL file that dot-sources the canonical file (see
    # the Redirection Trust note on the map entry above).
    if ($Link.loader) {
        $loaderLine = ". `"$src`""
        $existing = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
        if ($existing -and $existing.LinkType -in 'SymbolicLink', 'Junction') {
            if ($DryRun) {
                Write-Skip "${desc}: would replace symlink with loader stub"
                return
            }
            Remove-Item -LiteralPath $dst -Force
        } elseif ($existing -and ((Get-Content -LiteralPath $dst -Raw -ErrorAction SilentlyContinue).Trim() -eq $loaderLine)) {
            Write-Skip "$desc loader already in place"
            return
        } elseif ($DryRun) {
            Write-Skip "${desc}: would write loader stub -> $dst"
            return
        }
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        Set-Content -LiteralPath $dst -Value $loaderLine -Encoding utf8
        Write-OK "$desc (loader stub — avoids untrusted mount point)"
        return
    }

    # Skip if a link already points to the right place (full paths; Target may be string[])
    if (Test-Path -LiteralPath $dst -ErrorAction SilentlyContinue) {
        $item = Get-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType -in 'SymbolicLink', 'Junction') {
            $t = $item.Target
            if ($t -is [System.Array]) { $t = $t[0] }
            try {
                if ([IO.Path]::GetFullPath($t) -eq [IO.Path]::GetFullPath($src)) {
                    Write-Skip "$desc already linked"
                    return
                }
            } catch { }
        }
    }

    if ($DryRun) {
        Write-Skip "${desc}: would link $src -> $dst"
        return
    }

    New-Item -ItemType Directory -Path $dstDir -Force | Out-Null

    # Wrong link: remove (Copy-Item on links often fails). Plain file/dir: back up then remove.
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
        # Junction for directories (works without admin), symlink for files
        $linkType = if ((Get-Item -LiteralPath $src).PSIsContainer) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkType -Path $dst -Target $src -Force | Out-Null
        Write-OK "$desc ($($linkType.ToLower()))"
    } catch {
        Copy-Item $src $dst -Force -Recurse
        Write-Warn "$desc (copied — run as admin for symlinks)"
    }
}

# The WezTerm config moved from ~/.wezterm.lua to the ~/.config/wezterm junction.
function Remove-LegacyWeztermConfig {
    param([switch]$DryRun)
    $legacy = "$HOME\.wezterm.lua"
    if (-not (Test-Path -LiteralPath $legacy)) { return }
    if ($DryRun) {
        Write-Skip "Would remove legacy ~/.wezterm.lua (config lives in ~/.config/wezterm)"
        return
    }
    Remove-Item -LiteralPath $legacy -Force -ErrorAction SilentlyContinue
    Write-OK "Removed legacy ~/.wezterm.lua"
}
