# Optional FSRCNNX enhancement for an EXISTING mpv AppData configuration.
# Preview by default. Installs one shader and adds one keyboard binding.
# Does not replace mpv.conf, existing Lua scripts, or ModernZ settings.
[CmdletBinding()]
param([switch]$Install)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$configDir = Join-Path $env:APPDATA 'mpv'
$inputPath = Join-Path $configDir 'input.conf'
$shaderDir = Join-Path $configDir 'shaders'
$shaderPath = Join-Path $shaderDir 'FSRCNNX_x2_8-0-4-1.glsl'
$url = 'https://github.com/igv/FSRCNN-TensorFlow/releases/download/1.1/FSRCNNX_x2_8-0-4-1.glsl'
$binding = 'Ctrl+F8 change-list glsl-shaders toggle "~~/shaders/FSRCNNX_x2_8-0-4-1.glsl"'

if (-not (Test-Path -LiteralPath $inputPath -PathType Leaf)) {
    throw "Missing mpv input.conf: $inputPath. Set up the main mpv configuration first."
}
$configItem = Get-Item -LiteralPath $configDir -Force
$inputItem = Get-Item -LiteralPath $inputPath -Force
if (($configItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
    ($inputItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw 'Refusing to edit an AppData configuration link. Make it independent first.'
}
$mpvPaths = @(Get-Command mpv -All -ErrorAction SilentlyContinue |
    Where-Object { $_.Source -match '(?i)mpv\.(exe|com)$' } |
    Select-Object -ExpandProperty Source -Unique)
foreach ($exe in $mpvPaths) {
    $portable = Join-Path (Split-Path -Parent $exe) 'portable_config'
    if (Test-Path -LiteralPath $portable) {
        throw "portable_config overrides AppData: $portable. Run .\install.ps1 -Mode Diagnose and resolve it first."
    }
}
$alreadyBound = (Select-String -LiteralPath $inputPath -Pattern '^\s*Ctrl\+F8\s+change-list\s+glsl-shaders\s+toggle\s+' -Quiet)
if (-not $Install) {
    Write-Host 'PREVIEW: No changes made.' -ForegroundColor Yellow
    Write-Host "Shader: $shaderPath"
    Write-Host "Shader already exists: $(Test-Path -LiteralPath $shaderPath)"
    Write-Host "Ctrl+F8 binding exists: $alreadyBound"
    Write-Host "Source: $url"
    Write-Host 'Use -Install to add the shader and missing keybinding without replacing other mpv settings.'
    exit 0
}
if (-not $mpvPaths.Count) { Write-Warning 'mpv.exe not detected on PATH. Verify the player before testing.' }
if ($alreadyBound -and -not (Test-Path -LiteralPath $shaderPath)) {
    Write-Host 'Existing Ctrl+F8 binding detected. Downloading the shader only.' -ForegroundColor Yellow
}
if ($alreadyBound -and (Test-Path -LiteralPath $shaderPath)) {
    Write-Host 'FSRCNNX shader and Ctrl+F8 binding already present. Nothing changed.' -ForegroundColor Green
    exit 0
}

# Fetch into a temp file and check shader structure before touching AppData.
$temp = Join-Path $env:TEMP ('FSRCNNX-' + [guid]::NewGuid().ToString('N') + '.glsl')
try {
    Invoke-WebRequest -Uri $url -OutFile $temp -ErrorAction Stop
    $header = Get-Content -LiteralPath $temp -TotalCount 25 | Out-String
    if ((Get-Item -LiteralPath $temp).Length -lt 1024 -or $header -notmatch '//!HOOK|//!DESC') {
        throw 'Shader download failed validation. Existing mpv configuration was not changed.'
    }
    New-Item -ItemType Directory -Path $shaderDir -Force | Out-Null
    if (Test-Path -LiteralPath $shaderPath) {
        $shaderBackup = "$shaderPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $shaderPath -Destination $shaderBackup -ErrorAction Stop
        Write-Host "Previous shader backed up: $shaderBackup"
    }
    Copy-Item -LiteralPath $temp -Destination $shaderPath -Force -ErrorAction Stop
    if (-not $alreadyBound) {
        $backup = "$inputPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item -LiteralPath $inputPath -Destination $backup -ErrorAction Stop
        Add-Content -LiteralPath $inputPath -Value @(
            ''
            '# Optional FSRCNNX 2x low-resolution enhancement; disabled by default.'
            $binding
        ) -Encoding utf8
        Write-Host "input.conf backed up: $backup"
    }
    Write-Host 'FSRCNNX ready. Restart mpv; Ctrl+F8 toggles the shader ON/OFF.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
}
