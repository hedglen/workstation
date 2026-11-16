# Read-only Workstation 2.0 health check.
[CmdletBinding()]
param()
$root = Split-Path $PSScriptRoot -Parent
$checks = [ordered]@{
    'apps.json' = Test-Path (Join-Path $root 'apps.json')
    'install.ps1' = Test-Path (Join-Path $root 'install.ps1')
    'WinGet' = [bool](Get-Command winget -ErrorAction SilentlyContinue)
    'PowerShell 7' = [bool](Get-Command pwsh -ErrorAction SilentlyContinue)
    'WezTerm config' = Test-Path (Join-Path $root 'wezterm\wezterm.lua')
    'Oh My Posh theme' = Test-Path (Join-Path $root 'oh-my-posh\hedglab.omp.json')
}
$checks.GetEnumerator() | ForEach-Object {
    [pscustomobject]@{ Check = $_.Key; Passed = $_.Value }
} | Format-Table -AutoSize
if ($checks.Values -contains $false) { exit 1 }
