# Preview-first standalone PowerShell 7 profile installation.
# Copies profile and Oh My Posh theme into the user profile: NO symlinks, junctions,
# dot-sourced repository files, PATH edits, registry changes, or elevated permissions.
[CmdletBinding()]
param([switch]$Install)
$ErrorActionPreference = 'Stop'
$sourceProfile = Join-Path $PSScriptRoot 'profile.ps1'
$sourceTheme = Join-Path (Split-Path -Parent $PSScriptRoot) 'oh-my-posh\hedglab.omp.json'
$profileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
$targetProfile = Join-Path $profileDir 'Microsoft.PowerShell_profile.ps1'
$themeDir = Join-Path $profileDir 'Workstation'
$targetTheme = Join-Path $themeDir 'hedglab.omp.json'

foreach ($src in @($sourceProfile, $sourceTheme)) {
    if (-not (Test-Path -LiteralPath $src)) { throw "Missing source file: $src" }
}
Write-Host "Profile: $sourceProfile -> $targetProfile"
Write-Host "Theme:   $sourceTheme -> $targetTheme"
if (-not $Install) {
    Write-Host 'PREVIEW: no changes. Use -Install to copy the profile and theme with backups.' -ForegroundColor Yellow
    exit 0
}

# Refuse replacement of links, and back up all existing destinations before writing.
$destinations = @(
    @{ Source = $sourceProfile; Destination = $targetProfile },
    @{ Source = $sourceTheme; Destination = $targetTheme }
)
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($entry in $destinations) {
    $dst = $entry.Destination
    if (Test-Path -LiteralPath $dst) {
        $item = Get-Item -LiteralPath $dst -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Refusing to replace junction/symlink: $dst"
        }
        $backup = "$dst.backup.$timestamp"
        if (Test-Path -LiteralPath $backup) { throw "Backup already exists: $backup" }
    }
}
foreach ($entry in $destinations) {
    $src = $entry.Source
    $dst = $entry.Destination
    New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force | Out-Null
    if (Test-Path -LiteralPath $dst) {
        $backup = "$dst.backup.$timestamp"
        Copy-Item -LiteralPath $dst -Destination $backup -ErrorAction Stop
        Write-Host "Backed up: $backup" -ForegroundColor Yellow
    }
    Copy-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
    Write-Host "Installed: $dst" -ForegroundColor Green
}
Write-Host 'Standalone files installed. Open a new PowerShell 7 window to test.'
