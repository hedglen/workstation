# video-ocr-translate.ps1 — wrapper for video-ocr-translate.py
# Usage: .\video-ocr-translate.ps1 "path\to\video.mp4" [-Output out.mp4] [-Bar 0.18] [-DiffThreshold 8.0] [-FontSize 32] [-DryRun]

param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Video,

    [string]$Output,
    [float]$Bar = 0.18,
    [float]$DiffThreshold = 8.0,
    [int]$FontSize = 32,
    [string]$Font,
    [string]$Model,
    [switch]$DryRun
)

$python = "$HOME\workstation\tools\transcribe-env\Scripts\python.exe"
$script = "$PSScriptRoot\video-ocr-translate.py"

if (-not (Test-Path -LiteralPath $python)) {
    Write-Error "Python venv not found at $python. Run dotfiles\install.ps1 (creates tools\transcribe-env)."
    exit 1
}

$cmdArgs = @($script, $Video)
if ($Output)               { $cmdArgs += @("--output", $Output) }
if ($Bar -ne 0.18)         { $cmdArgs += @("--bar", $Bar) }
if ($DiffThreshold -ne 8.0){ $cmdArgs += @("--diff", $DiffThreshold) }
if ($FontSize -ne 32)      { $cmdArgs += @("--font-size", $FontSize) }
if ($Font)                 { $cmdArgs += @("--font", $Font) }
if ($Model)                { $cmdArgs += @("--model", $Model) }
if ($DryRun)               { $cmdArgs += "--dry-run" }

& $python @cmdArgs
