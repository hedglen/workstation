# Workstation mpv: preview first. No automatic Windows associations or shell modifications.
[CmdletBinding()]
param(
    [ValidateSet('Preview','Stage','Install')]
    [string]$Mode = 'Preview'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = $PSScriptRoot
$target = Join-Path $env:APPDATA 'mpv'

# mpv prefers portable_config beside mpv.exe over %APPDATA%\mpv.
# Detect it before installing so a successful install cannot silently load old settings.
function Get-PortableMpvConfigs {
    $seen = @{}
    $candidates = @()
    $commands = @(Get-Command mpv -All -ErrorAction SilentlyContinue)
    foreach ($command in $commands) {
        $exePath = [string]$command.Source
        if ($exePath -notmatch '(?i)mpv(?:\.exe|\.com)
# Pin tested upstream projects to immutable revisions.
$modernzCommit = '579897e8c974c380caa5017dc7b27a69123c1333'
$thumbfastCommit = '0f711de3138c9bd6718209d819ac54022c23ded2'
$upstream = @(
    @{ Path = 'scripts/modernz.lua'; Url = "https://raw.githubusercontent.com/Samillion/ModernZ/$modernzCommit/modernz.lua" },
    @{ Path = 'fonts/modernz-icons.ttf'; Url = "https://raw.githubusercontent.com/Samillion/ModernZ/$modernzCommit/modernz-icons.ttf" },
    @{ Path = 'scripts/thumbfast.lua'; Url = "https://raw.githubusercontent.com/po5/thumbfast/$thumbfastCommit/thumbfast.lua" }
)
$tracked = @(
    'mpv.conf','input.conf',
    'scripts/ab-loop-manager.lua','scripts/boss-key.lua',
    'scripts/favorites.lua','scripts/remember-volume.lua',
    'script-opts/modernz.conf','script-opts/thumbfast.conf'
)

if ($Mode -eq 'Preview') {
    Write-Host 'PREVIEW: no changes made.' -ForegroundColor Yellow
    Write-Host "Would stage $($tracked.Count) tracked config files plus $($upstream.Count) pinned upstream assets."
    Write-Host "Would keep the old configuration untouched for Mode=Stage."
    Write-Host "Mode=Install would back up $target and then replace it with the staged setup."
    Write-Host 'Use: .\install.ps1 -Mode Stage    # test separately with mpv --config-dir'
    Write-Host 'Use: .\install.ps1 -Mode Install  # replace active AppData configuration'
    exit 0
}

$stage = Join-Path $env:TEMP ('mpv-modernz-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
try {
    foreach ($relative in $tracked) {
        $src = Join-Path $root $relative
        $dest = Join-Path $stage $relative
        if (-not (Test-Path -LiteralPath $src)) { throw "Missing repository file: $relative" }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
    foreach ($asset in $upstream) {
        $dest = Join-Path $stage $asset.Path
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Write-Host "Downloading $($asset.Path)..."
        Invoke-WebRequest -Uri $asset.Url -OutFile $dest
        if ((Get-Item -LiteralPath $dest).Length -eq 0) { throw "Empty download: $($asset.Path)" }
    }
} catch {
    Remove-Item -LiteralPath $stage -Force -Recurse -ErrorAction SilentlyContinue
    throw
}

if ($Mode -eq 'Stage') {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $dest = Join-Path $desktop ('mpv-modernz-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if (Test-Path -LiteralPath $dest) { throw "Destination already exists: $dest" }
    Move-Item -LiteralPath $stage -Destination $dest
    Write-Host "Staged test config: $dest" -ForegroundColor Green
    Write-Host 'Test: mpv --config-dir="<paste staged path>" "<video path>"'
    exit 0
}

# Installation changes the active AppData mpv config only. No file associations.
$portableConfigs = @(Get-PortableMpvConfigs)
if ($portableConfigs.Count -gt 0) {
    $portableConfigs | Format-Table -AutoSize | Out-Host
    throw 'Refusing to install: portable_config is overriding AppData. Back up and remove/rename the relevant portable_config first. See mpv-config/README.md.'
}
if (Test-Path -LiteralPath $target) {
    $item = Get-Item -LiteralPath $target -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Remove-Item -LiteralPath $stage -Recurse -Force
        throw "Active path is a junction/symlink: $target. Remove or change it manually before installation."
    }
    $backup = "$target.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (Test-Path -LiteralPath $backup) { throw "Backup already exists: $backup" }
    Move-Item -LiteralPath $target -Destination $backup
    Write-Host "Old config backed up: $backup" -ForegroundColor Yellow
}
try {
    Move-Item -LiteralPath $stage -Destination $target
    Write-Host "Installed active mpv configuration: $target" -ForegroundColor Green
    if ($backup) {
        foreach ($relative in @('favorites.txt', 'volume.conf')) {
            $source = Join-Path $backup $relative
            if (Test-Path -LiteralPath $source) {
                Copy-Item -LiteralPath $source -Destination (Join-Path $target $relative) -Force
            }
        }
        $oldWatchLater = Join-Path $backup 'watch_later'
        if (Test-Path -LiteralPath $oldWatchLater) {
            Copy-Item -LiteralPath $oldWatchLater -Destination (Join-Path $target 'watch_later') -Recurse -Force
        }
        Write-Host 'Migrated available favorites, volume, and watch-later state from backup.'
    }
} catch {
    Write-Warning "Installation failed. Staged files remain at $stage. Restore the backup if needed."
    throw
}
) { continue }
        $dir = Split-Path -Parent $exePath
        if (-not $dir) { continue }
        $portable = Join-Path $dir 'portable_config'
        if (-not $seen.ContainsKey($portable)) {
            $seen[$portable] = $true
            if (Test-Path -LiteralPath $portable) {
                $item = Get-Item -LiteralPath $portable -Force
                $candidates += [pscustomobject]@{
                    Path = $portable
                    LinkType = $item.LinkType
                    Target = ($item.Target -join ', ')
                }
            }
        }
    }
    return $candidates
}

# Pin tested upstream projects to immutable revisions.
$modernzCommit = '579897e8c974c380caa5017dc7b27a69123c1333'
$thumbfastCommit = '0f711de3138c9bd6718209d819ac54022c23ded2'
$upstream = @(
    @{ Path = 'scripts/modernz.lua'; Url = "https://raw.githubusercontent.com/Samillion/ModernZ/$modernzCommit/modernz.lua" },
    @{ Path = 'fonts/modernz-icons.ttf'; Url = "https://raw.githubusercontent.com/Samillion/ModernZ/$modernzCommit/modernz-icons.ttf" },
    @{ Path = 'scripts/thumbfast.lua'; Url = "https://raw.githubusercontent.com/po5/thumbfast/$thumbfastCommit/thumbfast.lua" }
)
$tracked = @(
    'mpv.conf','input.conf',
    'scripts/ab-loop-manager.lua','scripts/boss-key.lua',
    'scripts/favorites.lua','scripts/remember-volume.lua',
    'script-opts/modernz.conf','script-opts/thumbfast.conf'
)

if ($Mode -eq 'Preview') {
    Write-Host 'PREVIEW: no changes made.' -ForegroundColor Yellow
    Write-Host "Would stage $($tracked.Count) tracked config files plus $($upstream.Count) pinned upstream assets."
    Write-Host "Would keep the old configuration untouched for Mode=Stage."
    Write-Host "Mode=Install would back up $target and then replace it with the staged setup."
    Write-Host 'Use: .\install.ps1 -Mode Stage    # test separately with mpv --config-dir'
    Write-Host 'Use: .\install.ps1 -Mode Install  # replace active AppData configuration'
    exit 0
}

$stage = Join-Path $env:TEMP ('mpv-modernz-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $stage | Out-Null
try {
    foreach ($relative in $tracked) {
        $src = Join-Path $root $relative
        $dest = Join-Path $stage $relative
        if (-not (Test-Path -LiteralPath $src)) { throw "Missing repository file: $relative" }
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Copy-Item -LiteralPath $src -Destination $dest -Force
    }
    foreach ($asset in $upstream) {
        $dest = Join-Path $stage $asset.Path
        New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
        Write-Host "Downloading $($asset.Path)..."
        Invoke-WebRequest -Uri $asset.Url -OutFile $dest
        if ((Get-Item -LiteralPath $dest).Length -eq 0) { throw "Empty download: $($asset.Path)" }
    }
} catch {
    Remove-Item -LiteralPath $stage -Force -Recurse -ErrorAction SilentlyContinue
    throw
}

if ($Mode -eq 'Stage') {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $dest = Join-Path $desktop ('mpv-modernz-test-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    if (Test-Path -LiteralPath $dest) { throw "Destination already exists: $dest" }
    Move-Item -LiteralPath $stage -Destination $dest
    Write-Host "Staged test config: $dest" -ForegroundColor Green
    Write-Host 'Test: mpv --config-dir="<paste staged path>" "<video path>"'
    exit 0
}

# Installation changes the active AppData mpv config only. No file associations.
# Portable-config setups can override AppData; see README before installing.
if (Test-Path -LiteralPath $target) {
    $item = Get-Item -LiteralPath $target -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Remove-Item -LiteralPath $stage -Recurse -Force
        throw "Active path is a junction/symlink: $target. Remove or change it manually before installation."
    }
    $backup = "$target.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (Test-Path -LiteralPath $backup) { throw "Backup already exists: $backup" }
    Move-Item -LiteralPath $target -Destination $backup
    Write-Host "Old config backed up: $backup" -ForegroundColor Yellow
}
try {
    Move-Item -LiteralPath $stage -Destination $target
    Write-Host "Installed active mpv configuration: $target" -ForegroundColor Green
    Write-Host 'Previously saved favorites/volume remain in the backup, if present.'
} catch {
    Write-Warning "Installation failed. Staged files remain at $stage. Restore the backup if needed."
    throw
}
