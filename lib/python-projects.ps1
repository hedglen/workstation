# =============================================================================
#   lib/python-projects.ps1
#   Venv creation + dependency install, uv-first with py/pip fallback.
#   Takes absolute paths so it covers repo projects (.venv in the project dir)
#   and out-of-repo venvs like tools\transcribe-env alike.
#   Requires lib/common.ps1. Dot-source; do not run directly.
# =============================================================================

function Install-PythonVenv {
    param(
        [Parameter(Mandatory)][string]$VenvDir,
        [Parameter(Mandatory)][string]$Requirements,
        [string]$DisplayName,
        [switch]$DryRun
    )
    if (-not $DisplayName) { $DisplayName = $VenvDir }

    if (-not (Test-Path $Requirements)) {
        Write-Warn "${DisplayName}: requirements file not found ($Requirements)"
        return
    }

    # uv is much faster and manifest-managed (astral-sh.uv); fall back to py + pip.
    $uv = Get-Command uv -ErrorAction SilentlyContinue
    $py = Get-Command py -ErrorAction SilentlyContinue
    if (-not $uv -and -not $py) {
        Write-Warn "Neither uv nor the Python launcher (py) is on PATH — skip venv for $DisplayName"
        return
    }

    $venvPy = Join-Path $VenvDir "Scripts\python.exe"
    if ($DryRun) {
        $tool = if ($uv) { "uv" } else { "pip" }
        if (Test-Path $venvPy) {
            Write-Skip "Would $tool install in $DisplayName (venv exists)"
        } else {
            Write-Skip "Would create venv ($tool) and install deps in $DisplayName"
        }
        return
    }

    if (-not (Test-Path $venvPy)) {
        if ($uv) { & uv venv $VenvDir } else { & py -3 -m venv $VenvDir }
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "venv creation failed for $DisplayName"
            return
        }
    }

    $prevEA = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($uv) {
        & uv pip install --python $venvPy -r $Requirements
    } else {
        # uv-created venvs have no pip; python -m pip only works on stdlib venvs
        & $venvPy -m pip install --upgrade pip 2>$null | Out-Null
        & $venvPy -m pip install -r $Requirements
    }
    $exit = $LASTEXITCODE
    $ErrorActionPreference = $prevEA

    if ($exit -eq 0) {
        Write-OK "Python venv: $DisplayName"
    } else {
        Write-Warn "dependency install exited $exit for $DisplayName"
    }
}
