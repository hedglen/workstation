# =============================================================================
#   PowerShell Profile — rjh
#   Managed via dotfiles: https://github.com/hedglen/dotfiles
# =============================================================================

# --- Secrets (not in git) ---
if (Test-Path "$HOME\.secrets.ps1") { . "$HOME\.secrets.ps1" }

# --- Session capabilities ---
$script:IsInteractiveTerminal = $false
try {
    $script:IsInteractiveTerminal = ($Host.Name -eq 'ConsoleHost' -or $Host.Name -eq 'Visual Studio Code Host') `
        -and -not [Console]::IsInputRedirected `
        -and -not [Console]::IsOutputRedirected
} catch {
    $script:IsInteractiveTerminal = $false
}

# --- Prompt (Oh My Posh) ---
if ($script:IsInteractiveTerminal) {
    try {
        $Host.UI.RawUI.BackgroundColor = 'Black'
        Clear-Host
    } catch {
        $script:IsInteractiveTerminal = $false
    }
}

if ($script:IsInteractiveTerminal -and (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    oh-my-posh init pwsh --config "$HOME\workstation\dotfiles\oh-my-posh\hedglab.omp.json" | Invoke-Expression
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    # zoxide only accepts "powershell" here (covers Windows PowerShell and pwsh)
    $zoxideInit = zoxide init powershell | Out-String
    if ($zoxideInit) { Invoke-Expression $zoxideInit }
}

# =============================================================================
#   Navigation
# =============================================================================

function c { Set-Location C:\ }
function d { Set-Location D:\ }
function tools { Set-Location "$HOME\workstation\tools" }
function psh { Set-Location "$HOME\workstation\tools\powershell" }
function home { Set-Location $HOME }
function dots { Set-Location "$HOME\workstation\dotfiles" }

# =============================================================================
#   System / User Helpers
# =============================================================================

function users {
    Get-LocalUser |
    Select-Object Name, Enabled, LastLogon |
    Format-Table -AutoSize
}

function admins {
    Get-LocalGroupMember Administrators |
    Select-Object ObjectClass, Name, PrincipalSource |
    Format-Table -AutoSize
}

# =============================================================================
#   Startup / Task Inspection
# =============================================================================

function Get-StartupList {
    Get-CimInstance Win32_StartupCommand |
    Select-Object Name, Command, Location, User |
    Sort-Object Name |
    Format-Table -AutoSize
}

function Get-UserTasks {
    Get-ScheduledTask |
    Where-Object { $_.TaskPath -notlike '\Microsoft*' } |
    Select-Object TaskName, TaskPath, State |
    Sort-Object TaskName |
    Format-Table -AutoSize
}

function Search-Startup {
    param([Parameter(Mandatory = $true)][string]$Pattern)
    $paths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
    )
    $result = foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ItemProperty $p | ForEach-Object {
                $_.PSObject.Properties |
                Where-Object {
                    $_.Name -notmatch '^PS' -and (
                        $_.Name -match $Pattern -or
                        ($_.Value -as [string]) -match $Pattern
                    )
                } |
                Select-Object @{n = 'Path'; e = { $p } }, Name, Value
            }
        }
    }
    if ($result) { $result | Format-Table -AutoSize }
    else { Write-Host "No startup entries matched: $Pattern" -ForegroundColor Yellow }
}

# =============================================================================
#   Daily Driver Helpers
# =============================================================================

function drives {
    Get-Volume |
    Where-Object DriveLetter |
    Select-Object `
    @{n = 'Drive'; e = { "{0}:" -f $_.DriveLetter } },
    FileSystemLabel,
    FileSystem,
    @{n = 'SizeGB'; e = { [math]::Round($_.Size / 1GB, 1) } },
    @{n = 'FreeGB'; e = { [math]::Round($_.SizeRemaining / 1GB, 1) } } |
    Sort-Object Drive |
    Format-Table -AutoSize
}

function Get-Uptime {
    $os = Get-CimInstance Win32_OperatingSystem
    $lastBoot = $os.LastBootUpTime
    $span = (Get-Date) - $lastBoot
    "{0}d {1}h {2}m" -f $span.Days, $span.Hours, $span.Minutes
}

function pkillf {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$WhatIf
    )
    $targets = Get-Process | Where-Object { $_.ProcessName -like "*$Name*" }
    if (-not $targets) {
        Write-Host "No matching processes for: $Name" -ForegroundColor Yellow
        return
    }
    $targets | Select-Object ProcessName, Id | Sort-Object ProcessName, Id | Format-Table -AutoSize
    if ($WhatIf) { return }
    $targets | Stop-Process -Force
    Write-Host "Stopped: $Name" -ForegroundColor Green
}

# sysinfo — quick hardware/OS snapshot
function sysinfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    [PSCustomObject]@{
        OS       = $os.Caption
        Uptime   = Get-Uptime
        RAM_GB   = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
        CPU      = $cpu.Name
        User     = "$env:USERDOMAIN\$env:USERNAME"
        Hostname = $env:COMPUTERNAME
    } | Format-List
}

# which — find command location (alias for Get-Command)
function which { param([string]$Name) (Get-Command $Name -ErrorAction SilentlyContinue)?.Source }

# touch — create empty file like Unix touch
function touch { param([string]$Path) New-Item -ItemType File -Path $Path -Force | Out-Null }

# grep — pipe-friendly wrapper
function grep { param([string]$Pattern) $input | Select-String $Pattern }

# reload — re-source the profile
function reload { . $PROFILE; Write-Host "Profile reloaded." -ForegroundColor Green }

# save-dots — commit and push all dotfile changes to GitHub
function save-dots {
    param([string]$Message = "update configs")
    Push-Location "$HOME\workstation\dotfiles"
    $status = git status --porcelain
    if (-not $status) {
        Write-Host "Nothing to save — dotfiles already up to date." -ForegroundColor DarkGray
    }
    else {
        git add -A
        git commit -m $Message
        git push
        Write-Host "Dotfiles saved to GitHub." -ForegroundColor Green
    }
    Pop-Location
}

# sync-dots — pull latest dotfiles from GitHub and re-apply configs (no app upgrades)
function sync-dots {
    & "$HOME\workstation\dotfiles\maintenance\update.ps1" -SkipApps
}

function Update-Dotfiles {
    & "$HOME\workstation\dotfiles\maintenance\update.ps1" @args
}

function Test-WorkstationHealth {
    & "$HOME\workstation\dotfiles\scripts\workstation-health.ps1" @args
}

# ask — plain-English terminal helper powered by Anthropic
function ask {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$Prompt
    )

    if (-not $Prompt) {
        Write-Host 'Usage: ask "what you want to do"' -ForegroundColor Yellow
        return
    }

    $script = "$HOME\workstation\dotfiles\powershell\ask.py"
    $python = (Get-Command python -ErrorAction SilentlyContinue)?.Source

    if (-not $python) {
        Write-Host "Python is not available on PATH." -ForegroundColor Red
        return
    }

    & $python $script @Prompt
}

# =============================================================================
#   Media Organizer
# =============================================================================

function orgmed {
    $py  = "$HOME\workstation\dotfiles\projects\media-organizer\.venv\Scripts\python.exe"
    $scr = "$HOME\workstation\dotfiles\projects\media-organizer\organize.py"
    & $py $scr @args
}

function orgmedx {
    $py  = "$HOME\workstation\dotfiles\projects\media-organizer\.venv\Scripts\python.exe"
    $scr = "$HOME\workstation\dotfiles\projects\media-organizer\organize.py"
    & $py $scr --dest x --apply
}

function ytdl {
    $py  = "$HOME\workstation\dotfiles\projects\ytdl\.venv\Scripts\python.exe"
    $scr = "$HOME\workstation\dotfiles\projects\ytdl\ytdl.py"
    & $py $scr @args
}
Set-Alias dl ytdl
function dll { yt-dlp --list-extractors @args }

function Update-MediaOrganizerPip {
    & "$HOME\workstation\dotfiles\projects\media-organizer\.venv\Scripts\python.exe" -m pip install --upgrade pip
}

function Update-MediaOrganizerDeps {
    & "$HOME\workstation\dotfiles\projects\media-organizer\.venv\Scripts\pip.exe" install -r "$HOME\workstation\dotfiles\projects\media-organizer\requirements.txt"
}

function Update-YtdlDeps {
    & "$HOME\workstation\dotfiles\projects\ytdl\.venv\Scripts\pip.exe" install -U -r "$HOME\workstation\dotfiles\projects\ytdl\requirements.txt"
}

function Update-TranscribeDeps {
    & "$HOME\workstation\tools\transcribe-env\Scripts\pip.exe" install -U -r "$HOME\workstation\dotfiles\scripts\requirements-transcribe.txt"
}

function Update-ProjectVenvs {
    & "$HOME\workstation\dotfiles\install.ps1" -NoApps
}

function scimitar { & "$HOME\workstation\dotfiles\corsair\scimitar.ps1" @args }

function trans {
    $py  = "$HOME\workstation\tools\transcribe-env\Scripts\python.exe"
    $scr = "$HOME\workstation\dotfiles\scripts\transcribe.py"
    & $py $scr @args
}

function vtrans {
    $py  = "$HOME\workstation\tools\transcribe-env\Scripts\python.exe"
    $scr = "$HOME\workstation\dotfiles\scripts\video-ocr-translate.py"
    & $py $scr @args
}
function fixsub { vtrans @args }

# =============================================================================
#   Aliases
# =============================================================================

Set-Alias ll           Get-ChildItem
Set-Alias la           Get-ChildItem
Set-Alias open         Invoke-Item
Set-Alias startup-list Get-StartupList
Set-Alias tasks-user   Get-UserTasks
Set-Alias startup-find Search-Startup
Set-Alias uptime       Get-Uptime
Set-Alias dots-update  Update-Dotfiles
Set-Alias update-all   Update-Dotfiles
Set-Alias dots-health  Test-WorkstationHealth
Set-Alias pip-upgrade  Update-MediaOrganizerPip
Set-Alias py-media-deps Update-MediaOrganizerDeps
Set-Alias py-ytdl-deps Update-YtdlDeps
Set-Alias py-transcribe-deps Update-TranscribeDeps
Set-Alias py-refresh-venvs Update-ProjectVenvs

# =============================================================================
#   PSReadLine
# =============================================================================

if ($script:IsInteractiveTerminal -and (Get-Module -ListAvailable -Name PSReadLine)) {
    try {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -Colors @{ InlinePrediction = "#64B5FF" }
    } catch {
        Write-Verbose "PSReadLine setup skipped: $_"
    }
}

# =============================================================================
#   Styling
# =============================================================================

if ($PSStyle) {
    $PSStyle.FileInfo.Directory = "`e[38;5;81m"   # soft cyan
    $PSStyle.FileInfo.Executable = "`e[38;5;220m"  # warm yellow
}

# =============================================================================
#   Startup Banner
# =============================================================================

if ($script:IsInteractiveTerminal) {
    # Banner lines: truecolor aligned with Neon Dark terminal (cyan / magenta / bold red / sky / orange / mint / gold quote)
    $esc = [char]27
    [Console]::WriteLine("${esc}[38;2;102;249;255m  drives  uptime  sysinfo  users  admins  startup-list  tasks-user  pkillf  reload${esc}[0m")
    [Console]::WriteLine("${esc}[38;2;233;84;255m  orgmed [--apply] [--dest x|movies|tv|music_videos]  ${esc}[38;2;255;20;200morgmedx${esc}[38;2;233;84;255m  -- organize R:\Media\x\dl${esc}[0m")
    [Console]::WriteLine("${esc}[1m${esc}[38;2;255;28;65m  ytdl <url> [--audio] [--quality 1080|720|480|best]   -- download video/audio${esc}[0m")
    [Console]::WriteLine("${esc}[38;2;100;181;255m  trans <path> [--model large-v3|medium|small] [--language en]  -- transcribe video to .srt + .md${esc}[0m")
    [Console]::WriteLine("${esc}[38;2;255;102;0m  save-dots [message]  — commit & push dotfiles to GitHub${esc}[0m")
    [Console]::WriteLine("${esc}[38;2;92;255;184m  sync-dots             — pull latest dotfiles & relink configs${esc}[0m")

    $quotes = @(
        # originals
        "You're not debugging. You're time travelling.",
        "AI writes code. You write the future.",
        "The bug you ignore today spawns tech debt tomorrow.",
        "Clarity comes not from code, but from thought before code.",
        "Refactor until it sings. Then refactor again.",
        # new
        "It works on my machine. Ship the machine.",
        "rm -rf and a prayer.",
        "The only valid measurement of code quality is WTFs per minute.",
        "git commit -m 'fix' for the 11th time today.",
        "It's not a bug, it's an undocumented feature with commitment issues.",
        "Any sufficiently advanced config file is indistinguishable from magic.",
        "First rule of optimisation: don't. Second rule: not yet.",
        "I don't always test my code, but when I do, I do it in production.",
        "sudo make me a sandwich.",
        "Weeks of coding can save you hours of planning.",
        "The computer was working fine until I touched it.",
        "Have you tried turning it off and turning it on again? I have. Twice.",
        "If it's stupid but it works, it's still stupid. Fix it later.",
        "git blame: a love letter to past you.",
        "One more 'quick fix' and I'm rewriting the whole thing.",
        "Stack Overflow is just outsourced memory.",
        "Winget upgrade --all and pray nothing breaks.",
        "Documentation? The code is self-documenting. (It's not.)",
        "The cloud is just someone else's computer having a bad day.",
        "I love deadlines. I love the whooshing noise they make as they go by.",
        "This is fine. Everything is fine. The terminal is on fire.",
        "Neon dark or go home.",
        "Copy-paste is a feature, not a crime.",
        "The fastest code is the code that never runs.",
        "I didn't choose the sysadmin life. The sysadmin life chose me."
    )
    [Console]::WriteLine("${esc}[38;2;255;212;71m  $(Get-Random -InputObject $quotes)${esc}[0m")
}
