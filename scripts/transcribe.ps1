# transcribe.ps1 — wrapper for transcribe.py
# Usage: .\transcribe.ps1 "path\to\video.ts" [-Model large-v3] [-Language en]

param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Video,

    [ValidateSet("tiny", "base", "small", "medium", "large-v2", "large-v3")]
    [string]$Model = "large-v3",

    [string]$Language
)

$python = "$HOME\workstation\tools\transcribe-env\Scripts\python.exe"
$script = "$PSScriptRoot\transcribe.py"

if (-not (Test-Path -LiteralPath $python)) {
    Write-Error "Python venv not found at $python. Run install.ps1 from $HOMEworkstation (creates tools\transcribe-env)."
    exit 1
}

$args = @($script, $Video, "--model", $Model)
if ($Language) { $args += @("--language", $Language) }

& $python @args
