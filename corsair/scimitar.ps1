# =============================================================================
#   corsair/scimitar.ps1
#   Scimitar Elite WL SE profile backup / version manager.
#
#   Usage:
#     scimitar backup  [-Name <string>]
#     scimitar list    [-n <int>]
#     scimitar restore [-Name <string>]
#     scimitar diff    [-From <string>] [-To <string>]
#     scimitar status
# =============================================================================

param(
    [Parameter(Position = 0)]
    [string]$Command,

    [string]$Name,
    [string]$From,
    [string]$To,
    [int]$n = 20
)

$ErrorActionPreference = 'Stop'
$WorkstationDir = Split-Path $PSScriptRoot -Parent
$BackupDir   = Join-Path $PSScriptRoot 'backups'
$iCUEDir     = "$env:APPDATA\Corsair\CUE5"

. (Join-Path $PSScriptRoot 'scimitar-lib.ps1')

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

function Write-Step { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$Msg) Write-Host "   OK  $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "   !!  $Msg" -ForegroundColor Yellow }
function Write-Info { param([string]$Msg) Write-Host "   --  $Msg" -ForegroundColor DarkGray }

# Source file map: readable name -> iCUE AppData path
function Get-SourceMap {
    $swProfile = Get-ChildItem "$iCUEDir\profiles\*.cueprofiledata" -ErrorAction SilentlyContinue |
                 Select-Object -First 1

    $map = [ordered]@{
        'hw-slot-1.cueprofiledata' = "$iCUEDir\hw_profiles\{2b220000-0010-0000-0000-000000000000}.cueprofiledata"
        'hw-slot-2.cueprofiledata' = "$iCUEDir\hw_profiles\{2b220000-0020-0000-0000-000000000000}.cueprofiledata"
        'hw-slot-3.cueprofiledata' = "$iCUEDir\hw_profiles\{2b220000-0030-0000-0000-000000000000}.cueprofiledata"
        'config.cuecfg'            = "$iCUEDir\config.cuecfg"
    }
    if ($swProfile) {
        $map['software.cueprofiledata'] = $swProfile.FullName
    }
    return $map
}

function Assert-iCUENotRunning {
    $proc = Get-Process -Name 'iCUE' -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host ""
        Write-Host "  ERROR: iCUE is running (PID $($proc.Id))." -ForegroundColor Red
        Write-Host "  Close iCUE before restoring profiles." -ForegroundColor Red
        Write-Host ""
        exit 1
    }
}

# Resolve a user-supplied name to a git ref (tag or commit)
function Resolve-Ref {
    param([string]$RefName)
    # Try as a scimitar/ tag first
    $tagRef = "scimitar/$RefName"
    $result = git -C $WorkstationDir rev-parse --verify $tagRef 2>$null
    if ($LASTEXITCODE -eq 0) { return $tagRef }
    # Try as a raw ref (commit sha, HEAD, etc.)
    $result = git -C $WorkstationDir rev-parse --verify $RefName 2>$null
    if ($LASTEXITCODE -eq 0) { return $RefName }
    Write-Host "  ERROR: ref '$RefName' not found (tried tag 'scimitar/$RefName' and raw ref)." -ForegroundColor Red
    exit 1
}

# -----------------------------------------------------------------------------
# Commands
# -----------------------------------------------------------------------------

function Invoke-Backup {
    Write-Step "Backing up Scimitar profiles"

    $map = Get-SourceMap
    foreach ($entry in $map.GetEnumerator()) {
        $dst = Join-Path $BackupDir $entry.Key
        $src = $entry.Value
        if (Test-Path $src) {
            Copy-Item $src $dst -Force
            Write-OK $entry.Key
        } else {
            Write-Warn "$($entry.Key) - source not found: $src"
        }
    }

    # Stage only the backups/ subtree
    git -C $WorkstationDir add "corsair/backups/"

    $status = git -C $WorkstationDir status --porcelain -- "corsair/backups/" 2>&1
    if (-not $status) {
        Write-Host ""
        Write-Info "No changes since last backup."
        return
    }

    # Build commit message using profile names
    $slot1Name = Get-ProfileName (Join-Path $BackupDir 'hw-slot-1.cueprofiledata')
    $slot2Name = Get-ProfileName (Join-Path $BackupDir 'hw-slot-2.cueprofiledata')
    $slot3Name = Get-ProfileName (Join-Path $BackupDir 'hw-slot-3.cueprofiledata')
    $profileSummary = ($slot1Name, $slot2Name, $slot3Name | Where-Object { $_ }) -join ' / '
    $commitMsg = "chore(corsair): backup scimitar profiles [$profileSummary]"

    git -C $WorkstationDir commit -m $commitMsg
    $sha = git -C $WorkstationDir rev-parse --short HEAD

    Write-OK "Committed as $sha"

    if ($Name) {
        $tag = "scimitar/$Name"
        $existing = git -C $WorkstationDir tag -l $tag
        if ($existing) {
            $response = Read-Host "   Tag '$tag' already exists. Overwrite? [y/N]"
            if ($response -notmatch '^[Yy]') {
                Write-Info "Tag skipped."
                return
            }
            git -C $WorkstationDir tag -f $tag
        } else {
            git -C $WorkstationDir tag $tag
        }
        Write-OK "Tagged as '$tag'"
    }
}

function Invoke-List {
    Write-Host ""
    Write-Host "  Scimitar profile backups" -ForegroundColor Cyan
    Write-Host ""

    $log = git -C $WorkstationDir log -$n --format="%H %h %as %s" -- "corsair/backups/" 2>&1
    if (-not $log) {
        Write-Info "No backups found."
        return
    }

    # Get all scimitar/* tags with their commit SHAs
    $tagMap = @{}
    $tags = git -C $WorkstationDir tag -l "scimitar/*" 2>&1
    foreach ($tag in $tags) {
        $sha = git -C $WorkstationDir rev-list -n 1 $tag 2>&1
        if ($sha) { $tagMap[$sha] = $tag -replace '^scimitar/', '' }
    }

    Write-Host ("  {0,-7} {1,-12} {2,-16} {3}" -f 'Hash', 'Date', 'Tag', 'Message') -ForegroundColor DarkGray
    Write-Host ("  " + ('-' * 70)) -ForegroundColor DarkGray

    foreach ($line in $log) {
        $parts    = $line -split ' ', 4
        $fullSha  = $parts[0]
        $shortSha = $parts[1]
        $date     = ($parts[2] -split 'T')[0]
        $msg      = $parts[3] -replace '^chore\(corsair\): backup scimitar profiles ', ''
        $tagName  = if ($tagMap[$fullSha]) { $tagMap[$fullSha] } else { '' }
        $tagColor = if ($tagName) { 'Green' } else { 'DarkGray' }

        Write-Host -NoNewline ("  {0,-7} {1,-12} " -f $shortSha, $date)
        Write-Host -NoNewline ("{0,-16} " -f $tagName) -ForegroundColor $tagColor
        Write-Host $msg -ForegroundColor DarkGray
    }
    Write-Host ""
}

function Invoke-Restore {
    Assert-iCUENotRunning

    $ref = if ($Name) { Resolve-Ref $Name } else { 'HEAD' }

    Write-Step "Restoring Scimitar profiles from $ref"

    $files = @(
        'hw-slot-1.cueprofiledata',
        'hw-slot-2.cueprofiledata',
        'hw-slot-3.cueprofiledata',
        'software.cueprofiledata',
        'config.cuecfg'
    )

    $map = Get-SourceMap

    foreach ($file in $files) {
        $gitPath = "corsair/backups/$file"
        $content = git -C $WorkstationDir show "${ref}:${gitPath}" 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $content) {
            Write-Info "$file - not found in $ref, skipping"
            continue
        }

        # Determine destination
        $dst = if ($map[$file]) { $map[$file] } else { $null }

        # software.cueprofiledata: restore to the current GUID path if it exists,
        # otherwise fall back to the AppData profiles dir with its backed-up name
        if ($file -eq 'software.cueprofiledata' -and -not $dst) {
            $dst = "$iCUEDir\profiles\$file"
        }

        if (-not $dst) {
            Write-Info "$file - no destination path, skipping"
            continue
        }

        $dstDir = Split-Path $dst -Parent
        if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory $dstDir -Force | Out-Null }

        [System.IO.File]::WriteAllText($dst, ($content -join "`n"), [System.Text.Encoding]::UTF8)
        Write-OK "$file -> $dst"
    }

    Write-Host ""
    Write-Host "  Profiles restored. Relaunch iCUE to apply." -ForegroundColor Cyan
    Write-Host ""
}

function Invoke-Diff {
    $toRef   = if ($To)   { Resolve-Ref $To }   else { 'HEAD' }
    $fromRef = if ($From) { Resolve-Ref $From }  else { "${toRef}~1" }

    $toLabel   = if ($To)   { $To }   else { 'HEAD' }
    $fromLabel = if ($From) { $From } else { "${toLabel}~1" }

    # Extract both sets of files into temp directories
    $tmpFrom = Join-Path $env:TEMP "scimitar-diff-from"
    $tmpTo   = Join-Path $env:TEMP "scimitar-diff-to"
    Remove-Item $tmpFrom, $tmpTo -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmpFrom, $tmpTo -Force | Out-Null

    $files = @('hw-slot-1.cueprofiledata', 'hw-slot-2.cueprofiledata', 'hw-slot-3.cueprofiledata', 'config.cuecfg')
    foreach ($file in $files) {
        $gitPath = "corsair/backups/$file"
        $fromContent = git -C $WorkstationDir show "${fromRef}:${gitPath}" 2>$null
        $toContent   = git -C $WorkstationDir show "${toRef}:${gitPath}"   2>$null
        if ($fromContent) { [System.IO.File]::WriteAllText("$tmpFrom\$file", ($fromContent -join "`n"), [System.Text.Encoding]::UTF8) }
        if ($toContent)   { [System.IO.File]::WriteAllText("$tmpTo\$file",   ($toContent   -join "`n"), [System.Text.Encoding]::UTF8) }
    }

    Show-ProfileDiff -FromDir $tmpFrom -ToDir $tmpTo -FromLabel $fromLabel -ToLabel $toLabel

    Remove-Item $tmpFrom, $tmpTo -Recurse -Force -ErrorAction SilentlyContinue
}

function Invoke-Status {
    # Compare live iCUE files against the last backup (HEAD)
    $hasBackup = git -C $WorkstationDir log -1 --format="%H" -- "corsair/backups/" 2>$null
    if (-not $hasBackup) {
        Write-Host ""
        Write-Info "No backups yet. Run: scimitar backup"
        Write-Host ""
        return
    }

    $tmpLive = Join-Path $env:TEMP "scimitar-status-live"
    Remove-Item $tmpLive -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmpLive -Force | Out-Null

    $map = Get-SourceMap
    foreach ($entry in $map.GetEnumerator()) {
        if (Test-Path $entry.Value) {
            Copy-Item $entry.Value (Join-Path $tmpLive $entry.Key)
        }
    }

    $tmpBack = Join-Path $env:TEMP "scimitar-status-back"
    Remove-Item $tmpBack -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $tmpBack -Force | Out-Null

    $files = @('hw-slot-1.cueprofiledata', 'hw-slot-2.cueprofiledata', 'hw-slot-3.cueprofiledata', 'config.cuecfg')
    foreach ($file in $files) {
        $content = git -C $WorkstationDir show "HEAD:corsair/backups/$file" 2>$null
        if ($content) { [System.IO.File]::WriteAllText("$tmpBack\$file", ($content -join "`n"), [System.Text.Encoding]::UTF8) }
    }

    Show-ProfileDiff -FromDir $tmpBack -ToDir $tmpLive -FromLabel 'last backup' -ToLabel 'live'

    Remove-Item $tmpLive, $tmpBack -Recurse -Force -ErrorAction SilentlyContinue
}

function Show-Help {
    Write-Host ""
    Write-Host "  scimitar - Scimitar Elite WL SE profile manager" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Commands:" -ForegroundColor White
    Write-Host "    backup  [-Name <tag>]       Back up current profiles (optionally tag)"
    Write-Host "    list    [-n <int>]           List recent backups (default: 20)"
    Write-Host "    restore [-Name <tag>]        Restore from tag or HEAD"
    Write-Host "    diff    [-From <ref>] [-To <ref>]  Diff two backups (default: HEAD~1..HEAD)"
    Write-Host "    status                       Compare live profiles to last backup"
    Write-Host ""
    Write-Host "  Examples:" -ForegroundColor White
    Write-Host "    scimitar backup -Name gaming"
    Write-Host "    scimitar list"
    Write-Host "    scimitar diff -From gaming"
    Write-Host "    scimitar restore -Name gaming"
    Write-Host "    scimitar status"
    Write-Host ""
}

# -----------------------------------------------------------------------------
# Dispatch
# -----------------------------------------------------------------------------

switch ($Command) {
    'backup'  { Invoke-Backup }
    'list'    { Invoke-List }
    'restore' { Invoke-Restore }
    'diff'    { Invoke-Diff }
    'status'  { Invoke-Status }
    default   { Show-Help }
}
