# Workstation profile: Windows PowerShell 7, Zed, Oh My Posh.
# To use: copy to $HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
$WorkstationRoot = Join-Path $HOME 'workstation'
$theme = Join-Path $WorkstationRoot 'oh-my-posh\hedglab.omp.json'
if ((Get-Command oh-my-posh -ErrorAction SilentlyContinue) -and (Test-Path $theme)) {
    oh-my-posh init pwsh --config $theme | Invoke-Expression
}
$env:EDITOR = 'zed'
function dots { Set-Location $WorkstationRoot }
function edit { & zed @args }
function apps-preview { & (Join-Path $WorkstationRoot 'install.ps1') }
function apps-check { & (Join-Path $WorkstationRoot 'install.ps1') -Validate -ContinueOnError }
function apps-install { & (Join-Path $WorkstationRoot 'install.ps1') -Install -ContinueOnError }
function workstation-update { & (Join-Path $WorkstationRoot 'maintenance\update.ps1') @args }
