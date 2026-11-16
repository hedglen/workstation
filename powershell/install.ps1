# Install a minimal PowerShell 7 loader for the repository's profile.
# Defaults to preview; backs up the existing profile instead of overwriting it.
[CmdletBinding()]
param([switch]$Install)
$ErrorActionPreference = 'Stop'
$repoProfile = Join-Path $PSScriptRoot 'profile.ps1'
if (-not (Test-Path -LiteralPath $repoProfile)) { throw "Missing profile: $repoProfile" }

# PowerShell 7 CurrentUserCurrentHost uses $PROFILE.CurrentUserCurrentHost.
# Running this script via pwsh yields its own host-specific path; prefer standard
# console host so PowerShell/Windows Terminal/WezTerm share the same profile.
$destination = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'
$escaped = $repoProfile.Replace("'", "''")
$loader = "# Workstation profile loader: edits belong in the Git repository.`r`n. '$escaped'`r`n"

Write-Host "Repository profile: $repoProfile"
Write-Host "Current-user profile: $destination"
if (-not $Install) {
    Write-Host '[PREVIEW] No files changed. Run with -Install to back up and replace the current-user profile.' -ForegroundColor Yellow
    exit 0
}
if (Test-Path -LiteralPath $destination) {
    $item = Get-Item -LiteralPath $destination -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Refusing to replace symbolic link or junction: $destination"
    }
    $existing = Get-Content -LiteralPath $destination -Raw
    if ($existing -eq $loader) {
        Write-Host 'Already installed; no changes needed.' -ForegroundColor Green
        exit 0
    }
    $backup = "$destination.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (Test-Path -LiteralPath $backup) { throw "Backup already exists: $backup" }
    Copy-Item -LiteralPath $destination -Destination $backup -ErrorAction Stop
    Write-Host "Previous profile backed up: $backup" -ForegroundColor Yellow
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
Set-Content -LiteralPath $destination -Value $loader -NoNewline -Encoding utf8
Write-Host "Installed PowerShell profile loader: $destination" -ForegroundColor Green
Write-Host 'Open a new PowerShell 7 window to test. Existing sessions are unchanged.'
