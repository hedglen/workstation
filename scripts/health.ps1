# Read-only Workstation 2.0 health check; no installs, config edits or deletions.
[CmdletBinding()]
param()
$root = Split-Path $PSScriptRoot -Parent
$manifestPath = Join-Path $root 'apps.json'
$manifest = if (Test-Path -LiteralPath $manifestPath) {
    Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
} else { $null }
$checks = [ordered]@{
    'apps.json exists' = Test-Path -LiteralPath $manifestPath
    'Exactly 37 curated packages' = [bool]($manifest -and $manifest.winget.Count -eq 37)
    'Workstation installer' = Test-Path -LiteralPath (Join-Path $root 'install.ps1')
    'WinGet available' = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    'PowerShell 7 available' = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
    'WezTerm config' = Test-Path -LiteralPath (Join-Path $root 'wezterm\wezterm.lua')
    'Oh My Posh theme' = Test-Path -LiteralPath (Join-Path $root 'oh-my-posh\hedglab.omp.json')
    'PowerShell profile' = Test-Path -LiteralPath (Join-Path $root 'powershell\profile.ps1')
    'mpv ModernZ settings' = Test-Path -LiteralPath (Join-Path $root 'mpv-config\script-opts\modernz.conf')
    'mpv setup and diagnostics' = Test-Path -LiteralPath (Join-Path $root 'mpv-config\install.ps1')
}
$checks.GetEnumerator() | ForEach-Object {
    [pscustomobject]@{ Check = $_.Key; Passed = $_.Value }
} | Format-Table -AutoSize

Write-Host ''
Write-Host 'mpv PATH/config audit (read-only):' -ForegroundColor Cyan
$mpvExecutables = @(
    Get-Command mpv -All -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -match '(?i)mpv\.(exe|com)$' } |
        Select-Object -ExpandProperty Source -Unique
)
if (-not $mpvExecutables.Count) {
    Write-Warning 'mpv not on PATH. WinGet install or PATH configuration may be needed.'
} else {
    $mpvExecutables | ForEach-Object { Write-Host "  $_" }
    $found = @{}
    foreach ($exe in $mpvExecutables) {
        $portable = Join-Path (Split-Path -Parent $exe) 'portable_config'
        if ($found.ContainsKey($portable)) { continue }
        $found[$portable] = $true
        if (Test-Path -LiteralPath $portable) {
            Write-Warning "Legacy portable_config overrides AppData: $portable"
        }
    }
    Write-Host "AppData mpv config exists: $(Test-Path -LiteralPath (Join-Path $env:APPDATA 'mpv'))"
}
if ($checks.Values -contains $false) { exit 1 }
