# Preview-first Workstation 2.0 maintenance.
[CmdletBinding()]
param([switch]$Upgrade, [switch]$ContinueOnError)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$manifest = Get-Content (Join-Path $root 'apps.json') -Raw | ConvertFrom-Json
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'WinGet is required.' }
$failed = @()
foreach ($app in $manifest.winget) {
    if (-not $Upgrade) {
        Write-Host "[PREVIEW] winget upgrade --id $($app.id) --exact"
        continue
    }
    & winget upgrade --id $app.id --exact --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) {
        $failed += "$($app.name): exit $LASTEXITCODE (may be up-to-date, not installed, or failed)"
        if (-not $ContinueOnError) { break }
    }
}
if (-not $Upgrade) { Write-Host 'Preview only. Run with -Upgrade to attempt upgrades.' }
if ($failed.Count) { $failed | ForEach-Object { Write-Warning $_ }; exit 1 }
