# Workstation mpv: preview first; never change file associations or PATH.
[CmdletBinding()]
param(
    [ValidateSet('Preview','Stage','Install','Diagnose')]
    [string]$Mode = 'Preview'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$root = $PSScriptRoot
$target = Join-Path $env:APPDATA 'mpv'

# mpv's portable_config beside its executable overrides the AppData config.
# Detection is read-only. Never delete or alter a legacy config automatically.
function Get-MpvExecutables {
    @(Get-Command mpv -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -match '(?i)mpv\.(exe|com)$' } |
        Select-Object -ExpandProperty Source -Unique)
}
function Get-PortableOverrides {
    $seen = @{}
    $result = @()
    foreach ($exe in @(Get-MpvExecutables)) {
        $portable = Join-Path (Split-Path -Parent $exe) 'portable_config'
        if ($seen.ContainsKey($portable)) { continue }
        $seen[$portable] = $true
        if (Test-Path -LiteralPath $portable) {
            $item = Get-Item -LiteralPath $portable -Force
            $result += [pscustomobject]@{
                Path = $portable
                LinkType = $item.LinkType
                Target = ($item.Target -join ', ')
            }
        }
    }
    return $result
}
if ($Mode -eq 'Diagnose') {
    Write-Host 'mpv executables on PATH (first takes precedence):' -ForegroundColor Cyan
    @(Get-MpvExecutables) | ForEach-Object { Write-Host "  $_" }
    Write-Host "AppData config: $target"
    Write-Host "AppData config exists: $(Test-Path -LiteralPath $target)"
    $overrides = @(Get-PortableOverrides)
    if ($overrides.Count) {
        Write-Warning 'portable_config overrides AppData for the corresponding executable.'
        $overrides | Format-Table -AutoSize | Out-Host
    } else {
        Write-Host 'No portable_config overrides detected on PATH.' -ForegroundColor Green
    }
    exit 0
}

# Tested upstream assets are pinned to immutable revisions.
$modernzCommit = '579897e8c974c380caa5017dc7b27a69123c1333'
$thumbfastCommit = '0f711de3138c9bd6718209d819ac54022c23ded2'
$upstream = @(
    @{ Path = 'scripts/modernz.lua'; Url = "https://raw.githubusercontent.com/Samillion/ModernZ/$modernzCommit/modernz.lua" },
    @{ Path = 'fonts/modernz-icons.ttf'; Url = "https://raw.githubusercontent.com/Samillion/ModernZ/$modernzCommit/modernz-icons.ttf" },
    @{ Path = 'scripts/thumbfast.lua'; Url = "https://raw.githubusercontent.com/po5/thumbfast/$thumbfastCommit/thumbfast.lua" },
    # FSRCNNX 1.1 official 2x shader by igv; automatically selected by adaptive-render.lua.
    @{ Path = 'shaders/FSRCNNX_x2_8-0-4-1.glsl'; Url = 'https://github.com/igv/FSRCNN-TensorFlow/releases/download/1.1/FSRCNNX_x2_8-0-4-1.glsl' }
)
$tracked = @(
    'mpv.conf','input.conf',
    'scripts/ab-loop-manager.lua','scripts/boss-key.lua','scripts/adaptive-render.lua',
    'scripts/favorites.lua','scripts/remember-volume.lua',
    'script-opts/modernz.conf','script-opts/thumbfast.conf'
)

if ($Mode -eq 'Preview') {
    Write-Host 'PREVIEW: no changes made.' -ForegroundColor Yellow
    Write-Host "Would install $($tracked.Count) tracked config files and $($upstream.Count) upstream assets (including adaptive FSRCNNX shader)."
    Write-Host "Would back up existing $target on Install."
    $overrides = @(Get-PortableOverrides)
    if ($overrides.Count) {
        Write-Warning 'portable_config override found. Install will refuse to proceed:'
        $overrides | Format-Table -AutoSize | Out-Host
    }
    Write-Host 'Use: .\install.ps1 -Mode Diagnose # verify mpv locations'
    Write-Host 'Use: .\install.ps1 -Mode Stage    # test an independent config'
    Write-Host 'Use: .\install.ps1 -Mode Install  # back up and replace AppData config'
    exit 0
}

if ($Mode -eq 'Install') {
    if (-not @(Get-MpvExecutables).Count) {
        throw 'mpv is not found on PATH. Install shinchiro.mpv first, then verify Get-Command mpv -All.'
    }
    $overrides = @(Get-PortableOverrides)
    if ($overrides.Count) {
        $overrides | Format-Table -AutoSize | Out-Host
        throw 'Refusing to install: portable_config overrides the active AppData config. Inspect, back up, and remove/rename the override manually first.'
    }
    if (Test-Path -LiteralPath $target) {
        $item = Get-Item -LiteralPath $target -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to replace a junction or symlink: $target"
        }
    }
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
        if ($asset.Path -like '*.glsl') {
            $header = Get-Content -LiteralPath $dest -TotalCount 20 -ErrorAction Stop | Out-String
            if ($header -notmatch '//!HOOK|//!DESC') { throw "Downloaded shader does not look like an mpv GLSL shader: $($asset.Path)" }
        }
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
    Write-Host 'Test with: mpv --config-dir="<staged folder>" "<video file>"'
    exit 0
}

# Install: copy local runtime state from old config, but not old scripts/settings.
$backup = $null
if (Test-Path -LiteralPath $target) {
    $backup = "$target.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (Test-Path -LiteralPath $backup) { throw "Backup already exists: $backup" }
    Move-Item -LiteralPath $target -Destination $backup
    Write-Host "Old mpv config backed up: $backup" -ForegroundColor Yellow
}
try {
    Move-Item -LiteralPath $stage -Destination $target
    if ($backup) {
        foreach ($relative in @('favorites.txt', 'volume.conf')) {
            $src = Join-Path $backup $relative
            if (Test-Path -LiteralPath $src) {
                Copy-Item -LiteralPath $src -Destination (Join-Path $target $relative) -Force
            }
        }
        $srcWatchLater = Join-Path $backup 'watch_later'
        if (Test-Path -LiteralPath $srcWatchLater) {
            Copy-Item -LiteralPath $srcWatchLater -Destination (Join-Path $target 'watch_later') -Recurse -Force
        }
    }
    Write-Host "Installed active mpv config: $target" -ForegroundColor Green
    Write-Host 'Favorites, volume and watch-later state preserved when present.'
} catch {
    Write-Warning "Install failed. The staged config remains at $stage; restore $backup if needed."
    throw
}
