# =============================================================================
#   dotfiles/lib/fonts.ps1
#   CaskaydiaCove Nerd Font install (per-user, no admin needed).
#   Requires lib/common.ps1. Dot-source; do not run directly.
# =============================================================================

function Install-NerdFontIfMissing {
    param([switch]$DryRun)

    $fontsDir  = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $regPath   = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $checkFont = 'CaskaydiaCove Nerd Font Regular (TrueType)'

    # Check HKCU first, then HKLM (system-wide install), then fall back to file presence
    $installed = (Get-ItemProperty $regPath -ErrorAction SilentlyContinue).$checkFont
    if (-not $installed) {
        $installed = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue).$checkFont
    }
    if (-not $installed) {
        $fontFile = Get-ChildItem "$fontsDir\CaskaydiaCove*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($fontFile) { $installed = $fontFile.FullName }
    }

    if ($installed) {
        Write-Skip "CaskaydiaCove Nerd Font already installed"
        return
    }
    if ($DryRun) {
        Write-Skip "Would download and install CaskaydiaCove Nerd Font"
        return
    }

    $tmpZip     = "$env:TEMP\CascadiaCode.zip"
    $tmpExtract = "$env:TEMP\CascadiaCode-nf"
    $fontUrl    = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip"

    Write-Host "   Downloading CaskaydiaCove Nerd Font..." -ForegroundColor DarkGray
    Invoke-WebRequest -Uri $fontUrl -OutFile $tmpZip -UseBasicParsing
    Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force

    if (-not (Test-Path $fontsDir)) { New-Item -ItemType Directory -Path $fontsDir -Force | Out-Null }

    $count = 0
    Get-ChildItem $tmpExtract -Filter "*.ttf" | ForEach-Object {
        $dst = Join-Path $fontsDir $_.Name
        Copy-Item $_.FullName $dst -Force
        $fontName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + " (TrueType)"
        Set-ItemProperty -Path $regPath -Name $fontName -Value $dst -Force
        $count++
    }

    Remove-Item $tmpZip, $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
    Write-OK "Installed $count font files to $fontsDir"
}
