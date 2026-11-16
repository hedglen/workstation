# Workstation 2.0. Preview by default; never performs system tweaks.
[CmdletBinding()]
param(
    [switch]$Validate,
    [switch]$Install,
    [switch]$ContinueOnError
)
$ErrorActionPreference = 'Stop'
if ($Validate -and $Install) { throw 'Choose either -Validate or -Install.' }
$manifestPath = Join-Path $PSScriptRoot 'apps.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "Missing manifest: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schemaVersion -ne 2) { throw 'Expected Workstation 2.0 manifest schemaVersion 2.' }
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'WinGet unavailable. Install Microsoft App Installer first.' }
$mode = if ($Install) { 'INSTALL' } elseif ($Validate) { 'VALIDATE' } else { 'PREVIEW' }
Write-Host "Workstation 2.0 | $mode" -ForegroundColor Cyan
$failed = [System.Collections.Generic.List[string]]::new()
$completed = [System.Collections.Generic.List[string]]::new()
$alreadyInstalled = [System.Collections.Generic.List[string]]::new()
foreach ($package in $manifest.winget) {
    $id = [string]$package.id
    $name = [string]$package.name
    if ($id -notmatch '^[A-Za-z0-9][A-Za-z0-9.+_-]*$') {
        $failed.Add("$name : invalid package ID")
        if (-not $ContinueOnError) { break }
        continue
    }
    if (-not ($Validate -or $Install)) { Write-Host "[PREVIEW] $name ($id)"; continue }
    Write-Host "[CHECK] $name ($id)" -ForegroundColor Cyan
    & winget show --id $id --exact --source winget --accept-source-agreements *> $null
    if ($LASTEXITCODE -ne 0) {
        $failed.Add("$name ($id): not found in winget")
        if (-not $ContinueOnError) { break }
        continue
    }
    if ($Validate) { $completed.Add($name); Write-Host "[VALID] $name" -ForegroundColor Green; continue }
    # Use the installed package ID, without restricting the list to one source.
    $installedOutput = (& winget list --id $id --exact --accept-source-agreements 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0 -and $installedOutput -match [regex]::Escape($id)) {
        $alreadyInstalled.Add($name)
        Write-Host "[SKIP] $name already installed"
        continue
    }
    & winget install --id $id --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -eq 0) { $completed.Add($name); Write-Host "[OK] $name" -ForegroundColor Green }
    else {
        $failed.Add("$name ($id): installer exit code $LASTEXITCODE")
        if (-not $ContinueOnError) { break }
    }
}
Write-Host "Summary: $($completed.Count) successes; $($alreadyInstalled.Count) already installed; $($failed.Count) failures."
if (-not ($Validate -or $Install)) { Write-Host 'Preview only: no changes made.' -ForegroundColor Yellow }
Write-Host "Pending manual/package review: $($manifest.verifyPackageId -join ', ')"
if ($failed.Count) {
    $failed | ForEach-Object { Write-Warning $_ }
    exit 1
}
