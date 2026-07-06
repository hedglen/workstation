# =============================================================================
#  mpv-config installer
#  Downloads mpv, yt-dlp, and this config to your system.
#  Run from PowerShell as Administrator (recommended) or normal user.
# =============================================================================

param(
[string]$InstallDir = "$env:USERPROFILE\workstation\tools\mpv",
[switch]$DryRun
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # speeds up Invoke-WebRequest

function Info  { param($m) Write-Host "[*] $m" -ForegroundColor Cyan }
function OK    { param($m) Write-Host "[+] $m" -ForegroundColor Green }
function Fatal { param($m) Write-Host "[!] $m" -ForegroundColor Red; exit 1 }

$configDir  = "$InstallDir\portable_config"
$configSrc  = [System.IO.Path]::GetFullPath($PSScriptRoot)

function SkipOrRun {
    param(
        [Parameter(Mandatory = $true)][string]$What,
        [Parameter(Mandatory = $true)][scriptblock]$Run
    )
    if ($DryRun) {
        Write-Host "[~] DRY RUN: $What" -ForegroundColor DarkGray
        return
    }
    & $Run
}

# -----------------------------------------------------------------------------
# 1. Create install directory
# -----------------------------------------------------------------------------
Info "Installing to $InstallDir"
SkipOrRun "Create install directory" { New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null }

# -----------------------------------------------------------------------------
# 2. Download mpv (shinchiro Windows builds — latest stable)
# -----------------------------------------------------------------------------
Info "Fetching latest mpv release..."
$mpvApi = Invoke-RestMethod "https://api.github.com/repos/shinchiro/mpv-winbuild-cmake/releases/latest"
$mpvAsset = $mpvApi.assets | Where-Object { $_.name -match "mpv-x86_64-\d+-git.*\.7z$" } | Select-Object -First 1
if (-not $mpvAsset) { Fatal "Could not find mpv x86_64 release asset." }

$mpvZip = "$env:TEMP\mpv-latest.7z"
Info "Downloading $($mpvAsset.name)..."
SkipOrRun "Download mpv archive to $mpvZip" { Invoke-WebRequest -Uri $mpvAsset.browser_download_url -OutFile $mpvZip }

# Extract with 7-Zip-compatible CLI (7-Zip, NanaZip, Scoop shims, etc.)
$sevenZip = $null
foreach ($cmdName in @('7z.exe', '7z')) {
    $cmd = Get-Command $cmdName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source)) {
        $sevenZip = $cmd.Source
        break
    }
}
if (-not $sevenZip) {
    $sevenZip = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe",
        "C:\Program Files\NanaZip\7z.exe",
        "C:\Program Files (x86)\NanaZip\7z.exe",
        "$env:LocalAppData\Programs\NanaZip\7z.exe"
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if ($sevenZip) {
    Info "Extracting mpv (using $sevenZip)..."
    SkipOrRun "Extract mpv into $InstallDir" { & $sevenZip x $mpvZip -o"$InstallDir" -y | Out-Null }
} else {
    Fatal "7z.exe not found (7-Zip, NanaZip, or another 7-Zip-compatible build). Install one and ensure 7z is on PATH, or install NanaZip / 7-Zip, then re-run this script."
}
OK "mpv extracted to $InstallDir"

# -----------------------------------------------------------------------------
# 3. Download yt-dlp
# -----------------------------------------------------------------------------
Info "Downloading yt-dlp..."
SkipOrRun "Download yt-dlp.exe to $InstallDir\\yt-dlp.exe" { Invoke-WebRequest -Uri "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe" -OutFile "$InstallDir\yt-dlp.exe" }
OK "yt-dlp downloaded"

# -----------------------------------------------------------------------------
# 4. Junction bundled config (this script's folder) → portable_config
#     (Config lives under hedglen/workstation as mpv-config/; standalone clone is the same tree.)
# -----------------------------------------------------------------------------
Info "Linking mpv config (junction)..."
$alreadyOk = $false
if (Test-Path -LiteralPath $configDir) {
    $item = Get-Item -LiteralPath $configDir -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $tgt = $item.Target
        if ($tgt -is [array] -and $tgt.Count -gt 0) { $tgt = $tgt[0] }
        $got = [System.IO.Path]::GetFullPath($tgt.TrimEnd('\', '/'))
        if ($got -ieq $configSrc) {
            Info "Config already linked → $configSrc"
            $alreadyOk = $true
        }
    }
}

if (-not $alreadyOk) {
    if ($DryRun) {
        if (Test-Path -LiteralPath $configDir) {
            Write-Host "[~] DRY RUN: Would replace $configDir with junction → $configSrc" -ForegroundColor DarkGray
        } else {
            Write-Host "[~] DRY RUN: Would create junction $configDir → $configSrc" -ForegroundColor DarkGray
        }
    } else {
        if (Test-Path -LiteralPath $configDir) {
            $item = Get-Item -LiteralPath $configDir -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Remove-Item -LiteralPath $configDir -Force
            } else {
                $bak = "$configDir.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
                Move-Item -LiteralPath $configDir -Destination $bak
                Write-Host "[*] Backed up existing portable_config to $bak" -ForegroundColor DarkGray
            }
        }
        try {
            New-Item -ItemType Junction -Path $configDir -Target $configSrc -Force | Out-Null
        } catch {
            Fatal "Could not create junction at $configDir — $_"
        }
    }
}
OK "Config at $configDir (→ $configSrc)"

# -----------------------------------------------------------------------------
# 5. Download ffmpeg (needed for chapter saving and other tools)
# -----------------------------------------------------------------------------
Info "Downloading ffmpeg..."
try {
    $ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
    $ffmpegZip = "$env:TEMP\ffmpeg.zip"
    SkipOrRun "Download ffmpeg zip to $ffmpegZip" { Invoke-WebRequest -Uri $ffmpegUrl -OutFile $ffmpegZip }
    SkipOrRun "Extract ffmpeg zip" { Expand-Archive -Path $ffmpegZip -DestinationPath "$env:TEMP\ffmpeg_tmp" -Force }
    $ffmpegExe = Get-ChildItem "$env:TEMP\ffmpeg_tmp" -Recurse -Filter "ffmpeg.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($ffmpegExe) {
        SkipOrRun "Copy ffmpeg.exe to $InstallDir\\ffmpeg.exe" { Copy-Item $ffmpegExe.FullName "$InstallDir\ffmpeg.exe" -Force }
        OK "ffmpeg installed"
    }
    SkipOrRun "Clean up ffmpeg temp files" {
        Remove-Item $ffmpegZip -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:TEMP\ffmpeg_tmp" -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "[~] ffmpeg download failed — get it from https://ffmpeg.org/download.html and place ffmpeg.exe in $InstallDir" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 6. Download HdrSwitcher into portable_config
# -----------------------------------------------------------------------------
Info "Downloading HdrSwitcher..."
try {
    $hdrApi   = Invoke-RestMethod "https://api.github.com/repos/Vaiz/HdrSwitcher/releases/latest"
    $hdrAsset = $hdrApi.assets | Where-Object { $_.name -eq "HdrSwitcher.zip" } | Select-Object -First 1
    if ($hdrAsset) {
        $hdrZip = "$env:TEMP\HdrSwitcher.zip"
        SkipOrRun "Download HdrSwitcher zip to $hdrZip" { Invoke-WebRequest -Uri $hdrAsset.browser_download_url -OutFile $hdrZip }
        SkipOrRun "Extract HdrSwitcher zip" { Expand-Archive -Path $hdrZip -DestinationPath "$env:TEMP\HdrSwitcher" -Force }
        SkipOrRun "Copy HdrSwitcher.exe to $configDir\\hdrswitch.exe" { Copy-Item "$env:TEMP\HdrSwitcher\HdrSwitcher.exe" "$configDir\hdrswitch.exe" -Force }
        OK "HdrSwitcher installed as hdrswitch.exe"
    } else {
        Write-Host "[~] HdrSwitcher not found — get it from https://github.com/Vaiz/HdrSwitcher/releases and place it as hdrswitch.exe in $configDir" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[~] HdrSwitcher download failed — get it from https://github.com/Vaiz/HdrSwitcher/releases and place it as hdrswitch.exe in $configDir" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 7. Create single-instance launcher (mpv-single.bat + mpv-single.ps1)
# -----------------------------------------------------------------------------
Info "Creating single-instance launcher..."
$batPath = "$InstallDir\mpv-single.bat"
$ps1Path = "$InstallDir\mpv-single.ps1"

SkipOrRun "Write mpv-single.bat" {
    @'
@echo off
powershell -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0mpv-single.ps1" "%~1"
'@ | Set-Content $batPath -Encoding ASCII
}

SkipOrRun "Write mpv-single.ps1" {
    @'
param([string]$File)

$mpv  = Join-Path $PSScriptRoot "mpv.exe"
$pipe = "mpvsocket"

try {
    $client = New-Object System.IO.Pipes.NamedPipeClientStream(".", $pipe, [System.IO.Pipes.PipeDirection]::Out)
    $client.Connect(300)
    $writer = New-Object System.IO.StreamWriter($client)
    $writer.AutoFlush = $true
    $cmd = '{"command":["loadfile","' + ($File -replace '\\', '\\\\') + '","replace"]}'
    $writer.WriteLine($cmd)
    $client.Dispose()
} catch {
    Start-Process $mpv -ArgumentList "`"$File`""
}
'@ | Set-Content $ps1Path -Encoding UTF8
}

SkipOrRun "Register mpv-single.bat as Open With handler" {
    $appRegPath = 'HKCU:\Software\Classes\Applications\mpv-single.bat'
    New-Item -Path "$appRegPath\shell\open\command" -Force | Out-Null
    Set-ItemProperty -Path "$appRegPath\shell\open\command" -Name '(Default)' `
        -Value "cmd.exe /c `"`"$batPath`" `"%1`"`"" -Force
    Set-ItemProperty -Path $appRegPath -Name 'FriendlyAppName' -Value 'mpv (single instance)' -Force

    $exts = @('.mkv','.mp4','.avi','.mov','.wmv','.flv','.webm','.m4v','.ts','.m2ts','.mpg','.mpeg')
    foreach ($ext in $exts) {
        New-Item -Path "HKCU:\Software\Classes\$ext\OpenWithList\mpv-single.bat" -Force | Out-Null
    }
}
OK "Single-instance launcher created and registered"

# -----------------------------------------------------------------------------
# 8. Create desktop shortcut
# -----------------------------------------------------------------------------
Info "Creating desktop shortcut..."
$mpvExe = Get-ChildItem "$InstallDir" -Filter "mpv.exe" -Recurse | Select-Object -First 1
if ($mpvExe) {
    SkipOrRun "Create desktop shortcut mpv.lnk" {
        $shell    = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut("$env:USERPROFILE\Desktop\mpv.lnk")
        $shortcut.TargetPath       = $mpvExe.FullName
        $shortcut.WorkingDirectory = $mpvExe.DirectoryName
        $shortcut.Save()
    }
    OK "Desktop shortcut created"
}

# -----------------------------------------------------------------------------
# 8. Add mpv to user PATH
# -----------------------------------------------------------------------------
if ($mpvExe) {
    $mpvDir     = $mpvExe.DirectoryName
    $currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    if ($currentPath -notlike "*$mpvDir*") {
        SkipOrRun "Add mpv dir to user PATH" { [Environment]::SetEnvironmentVariable("PATH", "$currentPath;$mpvDir", "User") }
        OK "Added mpv to user PATH (restart terminal to take effect)"
    }
}

Write-Host ""
OK "Done! mpv is installed at $InstallDir"
Write-Host "    Config: $configDir" -ForegroundColor Gray
if ($mpvExe) { Write-Host "    Run:    $($mpvExe.FullName)" -ForegroundColor Gray }
