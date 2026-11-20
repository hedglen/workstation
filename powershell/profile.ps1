# Workstation PowerShell 7 profile. Installed as an independent user-profile copy.
# No dot-sourcing from Git; no dependency on where the repository is checked out.
$workstationTheme = Join-Path $PSScriptRoot 'Workstation\hedglab.omp.json'
if ((Get-Command oh-my-posh -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $workstationTheme)) {
    oh-my-posh init pwsh --config $workstationTheme | Invoke-Expression
}
$env:EDITOR = 'zed'

# Repo helpers are optional. They locate the canonical checkout when invoked,
# and have no effect at PowerShell startup when the repository is absent.
function Get-WorkstationRoot {
    # Prefer an explicit override, then the fresh-PC canonical path.
    $candidates = @($env:WORKSTATION_ROOT, (Join-Path $HOME 'workstation'))
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath (Join-Path $candidate 'apps.json'))) {
            return $candidate
        }
    }
    Write-Warning 'Workstation repo not found. Set WORKSTATION_ROOT or clone to $HOME\workstation.'
    return $null
}
function dots {
    $repo = Get-WorkstationRoot
    if ($repo) { Set-Location $repo }
}
function edit { & zed @args }
function apps-preview {
    $repo = Get-WorkstationRoot
    if ($repo) { & (Join-Path $repo 'install.ps1') }
}
function apps-check {
    $repo = Get-WorkstationRoot
    if ($repo) { & (Join-Path $repo 'install.ps1') -Validate -ContinueOnError }
}
function apps-install {
    $repo = Get-WorkstationRoot
    if ($repo) { & (Join-Path $repo 'install.ps1') -Install -ContinueOnError }
}
function workstation-update {
    $repo = Get-WorkstationRoot
    if ($repo) { & (Join-Path $repo 'maintenance\update.ps1') @args }
}
Write-Host 'Update WinGet apps: winget upgrade --all' -ForegroundColor DarkGray
