local distro = require 'modules.distro'
local paths = require 'modules.paths'
local spawn = require 'modules.spawn'

local M = {}

M.system_helper_cmd = [[
Clear-Host
$now = Get-Date
$os = Get-CimInstance Win32_OperatingSystem
$uptime = $now - $os.LastBootUpTime
$ips = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.PrefixOrigin -ne 'WellKnown' } |
  Select-Object -Unique InterfaceAlias, IPAddress
$vpnAdapters = Get-NetAdapter -ErrorAction SilentlyContinue |
  Where-Object { $_.InterfaceDescription -match 'VPN|TAP|TUN|WireGuard|ProtonVPN' -or $_.Name -match 'VPN|WireGuard|ProtonVPN' } |
  Select-Object Name, Status
$drives = Get-PSDrive -PSProvider FileSystem |
  Where-Object { $_.Name -match '^[A-Z]$' } |
  Sort-Object Name

function Format-Bytes([double]$bytes) {
  if ($bytes -ge 1TB) { return ('{0:N1} TB' -f ($bytes / 1TB)) }
  if ($bytes -ge 1GB) { return ('{0:N1} GB' -f ($bytes / 1GB)) }
  return ('{0:N0} MB' -f ($bytes / 1MB))
}

Write-Host (' Time:   ' + $now.ToString('yyyy-MM-dd hh:mm tt')) -ForegroundColor Cyan
Write-Host (' Uptime: ' + ('{0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes)) -ForegroundColor Cyan
Write-Host (' Host:   ' + $env:COMPUTERNAME) -ForegroundColor Cyan
if ($vpnAdapters) {
  $activeVpn = $vpnAdapters | Where-Object Status -eq 'Up' | Select-Object -First 1
  if ($activeVpn) {
    Write-Host (' VPN:    connected (' + $activeVpn.Name + ')') -ForegroundColor Green
  } else {
    Write-Host (' VPN:    adapters found, not connected') -ForegroundColor Yellow
  }
} else {
  Write-Host (' VPN:    no VPN adapter detected') -ForegroundColor DarkGray
}

try {
  $publicIp = (& curl.exe -s --max-time 3 https://api.ipify.org).Trim()
  if ($publicIp) {
    Write-Host (' Public: ' + $publicIp) -ForegroundColor Cyan
  } else {
    Write-Host (' Public: unavailable') -ForegroundColor DarkGray
  }
} catch {
  Write-Host (' Public: unavailable') -ForegroundColor DarkGray
}

Write-Host ''

Write-Host 'Drives:' -ForegroundColor Cyan
foreach ($drive in $drives) {
  Write-Host (' ' + $drive.Name + ': ') -NoNewline -ForegroundColor White
  Write-Host ((Format-Bytes $drive.Free) + ' free') -NoNewline -ForegroundColor Green
  Write-Host (' / ' + (Format-Bytes ($drive.Used + $drive.Free)) + ' total') -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'IPv4:' -ForegroundColor Cyan
if ($ips) {
  foreach ($ip in $ips) {
    Write-Host (' ' + $ip.InterfaceAlias + ': ') -NoNewline -ForegroundColor White
    Write-Host $ip.IPAddress -ForegroundColor DarkCyan
  }
} else {
  Write-Host ' no active IPv4 addresses found' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Helpers:' -ForegroundColor Cyan
Write-Host ' drives       uptime       sysinfo      users        admins' -ForegroundColor DarkGray
Write-Host ' startup-list tasks-user   pkillf       reload       sync-dots' -ForegroundColor DarkGray
Write-Host ' orgmed       ytdl         trans        save-dots' -ForegroundColor DarkGray
Write-Host ''
function _u($cmd, $desc) {
  Write-Host '  ' -NoNewline
  Write-Host $cmd -NoNewline -ForegroundColor Yellow
  Write-Host ('  ' + $desc) -ForegroundColor DarkGray
}

Write-Host 'STAY UP TO DATE - type these, in order' -ForegroundColor Magenta
_u 'update-all -DryRun' 'preview everything; changes nothing'
_u 'update-all' 'THE update: dotfiles pull + relink, winget, scoop, python venvs'
_u 'start ms-settings:windowsupdate' 'Windows Update (check weekly, reboot if asked)'
Write-Host ''
Write-Host 'AFTER YOU EDIT CONFIGS' -ForegroundColor Cyan
_u 'save-dots "msg"' 'commit + push dotfiles to GitHub'
_u 'reload' 're-source the pwsh profile in this shell'
Write-Host ''
Write-Host 'IF SOMETHING SEEMS BROKEN' -ForegroundColor Cyan
_u 'dots-health' 'check workstation layout + key tools'
_u 'sync-dots' 're-pull + relink configs only (no app upgrades)'
_u 'py-refresh-venvs' 'rebuild the python venvs'
Write-Host ''
Write-Host 'ONE PIECE AT A TIME (optional)' -ForegroundColor Cyan
_u 'winget upgrade --all' 'every winget app'
_u 'scoop status' 'list outdated CLI tools'
_u 'scoop update *' 'update all CLI tools'
_u 'py-media-deps / py-ytdl-deps / py-transcribe-deps' 'one venv each'
Write-Host ''
]]

-- Mirrors the categories in apps/scoop-packages.json — every scoop tool gets a row.
M.toolbelt_helper_cmd = [[
Clear-Host
& {
  function _cliRow($cmd, $desc) {
    Write-Host '  ' -NoNewline
    Write-Host $cmd -NoNewline -ForegroundColor Yellow
    Write-Host ('  ' + $desc) -ForegroundColor DarkGray
  }
  Write-Host 'Toolbelt - Scoop CLI cheat sheet' -ForegroundColor Magenta
  Write-Host 'Everything below installs from apps/scoop-packages.json.' -ForegroundColor DarkGray
  Write-Host ''

  Write-Host 'Search & navigate' -ForegroundColor Cyan
  _cliRow 'rg pattern' 'search file contents (-l = filenames only)'
  _cliRow 'fd name' 'find files by name (respects .gitignore)'
  _cliRow 'eza -la --git' 'modern ls (git column inside a repo)'
  _cliRow 'fzf' 'fuzzy picker; pipe lines in (fd | fzf)'
  _cliRow 'z / zi' 'zoxide: jump to visited dirs (zi = interactive)'
  _cliRow 'scoop-search term' 'find installable scoop packages'
  Write-Host ''

  Write-Host 'View & edit' -ForegroundColor Cyan
  _cliRow 'bat file' 'cat with syntax highlighting + line numbers'
  _cliRow 'glow file.md' 'render markdown in the terminal (glow . = browse)'
  _cliRow 'less file' 'plain pager (q quits, / searches)'
  _cliRow 'sd "old" "new" file' 'find & replace without sed syntax'
  Write-Host ''

  Write-Host 'Git & GitHub' -ForegroundColor Cyan
  _cliRow 'lazygit' 'full-screen git TUI'
  _cliRow 'git diff' 'delta pager via gitconfig; n/N jump files, q quits'
  _cliRow 'gh' 'GitHub CLI: pr, issue, repo (gh auth login once)'
  _cliRow 'git lfs status' 'large-file storage (git-lfs)'
  Write-Host ''

  Write-Host 'Data & media' -ForegroundColor Cyan
  _cliRow 'jq ".key" file.json' 'query/transform JSON'
  _cliRow 'yq ".key" file.yaml' 'same idea for YAML/XML/CSV'
  _cliRow 'exiftool file' 'read/write media metadata (dates, tags, codecs)'
  Write-Host ''

  Write-Host 'System & files' -ForegroundColor Cyan
  _cliRow 'btm / bottom' 'modern htop: CPU, mem, disk, network dashboard'
  _cliRow 'dust' 'disk usage tree, biggest first'
  _cliRow 'neofetch' 'system info banner with cyberpunk neon theme'
  _cliRow 'gsudo cmd' 'run one command elevated, same window'
  _cliRow 'hyperfine "cmd"' 'benchmark a command (warmup + stats)'
  _cliRow 'rclone ls remote:' 'cloud storage sync (rclone config first)'
  _cliRow 'wget url' 'plain downloader for scripts'
  Write-Host ''

  Write-Host 'Docs & task running' -ForegroundColor Cyan
  _cliRow 'pandoc in.md -o out.docx' 'convert between document formats'
  _cliRow 'just' 'run recipes from a justfile'
  _cliRow 'tldr cmd' 'example-first help for any CLI (tealdeer)'
  Write-Host ''

  Write-Host 'PowerShell profile' -ForegroundColor Cyan
  _cliRow 'll / la' 'Get-ChildItem'
  _cliRow 'reload' 're-source profile.ps1'
  _cliRow 'which name' 'resolve a command to its path'
  _cliRow 'grep pat' 'pipeline: ... | grep pat (Select-String)'
  _cliRow 'touch path' 'create empty file'
  _cliRow 'dots / tools / home' 'cd shortcuts (see profile.ps1)'
  Write-Host ''

  Write-Host 'Per-tool notes: apps/scoop-packages.md | full map: docs/workstation-tools.md' -ForegroundColor DarkCyan
  Write-Host ''
}
]]

M.claude_helper_cmd = [[
Clear-Host
& {
  function _row($cmd, $desc) {
    Write-Host '  ' -NoNewline
    Write-Host $cmd -NoNewline -ForegroundColor Yellow
    Write-Host ('  ' + $desc) -ForegroundColor DarkGray
  }
  $wslDistro = ']]
  .. distro.wsl_distro
  .. [['
  $claudeVer = (wsl.exe -d $wslDistro bash -lc 'claude --version 2>/dev/null' 2>$null)
  if ($claudeVer) { $claudeVer = $claudeVer.Trim() } else { $claudeVer = '' }
  $authStatus = (wsl.exe -d $wslDistro bash -lc 'claude auth status --text 2>/dev/null || claude auth status 2>/dev/null' 2>$null)
  if ($authStatus) { $authStatus = ($authStatus -join ' ').Trim() } else { $authStatus = '' }

  Write-Host 'Claude - WSL quick sheet' -ForegroundColor Magenta
  Write-Host 'Planning, architecture, implementation, and long-form reasoning.' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host ' Status' -ForegroundColor Cyan
  Write-Host '  Version: ' -NoNewline -ForegroundColor White
  if ($claudeVer) {
    Write-Host $claudeVer -ForegroundColor Green
  } else {
    Write-Host 'not installed' -ForegroundColor DarkGray
  }
  Write-Host '  Auth:    ' -NoNewline -ForegroundColor White
  if ($authStatus -match 'loggedIn|Logged in|authenticated|subscriptionType') {
    Write-Host 'ok' -ForegroundColor Green
  } elseif ($authStatus) {
    Write-Host $authStatus -ForegroundColor Yellow
  } else {
    Write-Host 'unavailable' -ForegroundColor DarkGray
  }
  Write-Host ''

  Write-Host 'When to start here' -ForegroundColor Cyan
  _row 'Plan a refactor' 'ask for options + tradeoffs before editing'
  _row 'Review a PR' 'focus on bugs, regressions, and test gaps'
  _row 'Write docs' 'draft README/runbook/checklist content'
  _row 'Implement a change' 'edit files, run checks, and verify behavior'
  Write-Host ''

  Write-Host 'In-session' -ForegroundColor Cyan
  _row '/plan' 'switch to planning before implementation'
  _row '/review' 'review a pull request or local changes'
  _row '/compact' 'shrink long conversation history'
  _row '/resume' 'pick up a previous session'
  _row '/model' 'change the active model'
  _row '/permissions' 'inspect or change tool permissions'
  _row '/context' 'inspect context window usage'
  _row '/help' 'show all available commands'
  Write-Host ''

  Write-Host 'Headless / scripting' -ForegroundColor Cyan
  _row 'claude -p "..."' 'run one task non-interactively'
  _row 'claude -c' 'continue the latest conversation in this directory'
  _row 'claude -r' 'select and resume a previous conversation'
  _row 'claude --model name' 'choose a model for the session'
  _row 'claude --permission-mode plan' 'start read-only in plan mode'
  _row 'claude update' 'upgrade the CLI'
  Write-Host ''

  Write-Host 'Prompt pattern' -ForegroundColor Cyan
  _row 'Goal' 'state the outcome and intended behavior'
  _row 'Constraints' 'compatibility, scope, and behavior to preserve'
  _row 'Acceptance checks' 'tests, lint, build, or exact expected output'
  _row 'Relevant paths / errors' 'include files and unedited command output'
  Write-Host ''

  Write-Host 'WSL paths' -ForegroundColor Cyan
  _row '/mnt/c/Users/rjh/workstation' 'workstation root (left pane CWD)'
  _row '.../dotfiles' 'configs, scripts, wezterm'
  _row '~/.claude/settings.json' 'Claude Code settings'
  _row '~/.claude/' 'sessions, projects, and local state'
  Write-Host ''

  Write-Host 'Auth & diagnostics' -ForegroundColor Cyan
  _row 'claude auth status' 'show current authentication state'
  _row 'claude auth login' 'authenticate or re-authenticate'
  _row 'claude doctor' 'diagnose configuration and runtime issues'
  _row '/doctor' 'run health checks inside a session'
  Write-Host ''

  Write-Host 'Tab workflow' -ForegroundColor Cyan
  Write-Host '  Claude tab  -> plan, reason, implement, review' -ForegroundColor DarkGray
  Write-Host '  Grok tab    -> research and second opinions' -ForegroundColor DarkGray
  Write-Host '  Codex tab   -> implement, test, review' -ForegroundColor DarkGray
  Write-Host '  Vibe tab    -> Mistral agent, agents, skills' -ForegroundColor DarkGray
  Write-Host '  Git tab     -> inspect, commit, push' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host 'CLI help: claude --help | in-session help: /help' -ForegroundColor DarkCyan
  Write-Host ''
}
]]

M.codex_helper_cmd = [[
Clear-Host
& {
  function _row($cmd, $desc) {
    Write-Host '  ' -NoNewline
    Write-Host $cmd -NoNewline -ForegroundColor Yellow
    Write-Host ('  ' + $desc) -ForegroundColor DarkGray
  }
  $wslDistro = ']]
  .. distro.wsl_distro
  .. [['
  $codexVer = (wsl.exe -d $wslDistro bash -lc 'codex --version 2>/dev/null' 2>$null)
  if ($codexVer) { $codexVer = $codexVer.Trim() } else { $codexVer = '' }
  # Codex writes login status to stderr, so merge both streams before matching it.
  $authStatus = (wsl.exe -d $wslDistro bash -lc 'codex login status 2>&1' 2>$null)
  if ($authStatus) { $authStatus = ($authStatus -join ' ').Trim() } else { $authStatus = '' }

  Write-Host 'Codex - WSL quick sheet' -ForegroundColor Magenta
  Write-Host 'Implementation agent; edits, tests, reviews, and automation.' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host ' Status' -ForegroundColor Cyan
  Write-Host '  Version: ' -NoNewline -ForegroundColor White
  if ($codexVer) {
    Write-Host $codexVer -ForegroundColor Green
  } else {
    Write-Host 'not installed' -ForegroundColor DarkGray
  }
  Write-Host '  Auth:    ' -NoNewline -ForegroundColor White
  if ($authStatus -match 'Logged in') {
    Write-Host 'ok' -ForegroundColor Green
  } elseif ($authStatus) {
    Write-Host $authStatus -ForegroundColor Yellow
  } else {
    Write-Host 'unavailable' -ForegroundColor DarkGray
  }
  Write-Host ''

  Write-Host 'When to start here' -ForegroundColor Cyan
  _row 'Implement a scoped change' 'edit files, run checks, verify the diff'
  _row 'Diagnose a failure' 'trace logs, tests, and configuration'
  _row 'Review a change' 'find bugs, regressions, and missing tests'
  _row 'Automate a task' 'scripts, migrations, and repeatable workflows'
  Write-Host ''

  Write-Host 'In-session' -ForegroundColor Cyan
  _row '/plan' 'switch to planning before implementation'
  _row '/review' 'review the current changes'
  _row '/diff' 'show the working-tree diff'
  _row '/status' 'show session and context details'
  _row '/compact' 'shrink long conversation history'
  _row '/resume' 'pick up a previous session'
  _row '/model' 'change model or reasoning level'
  _row '/permissions' 'change approval and sandbox policy'
  Write-Host ''

  Write-Host 'Headless / scripting' -ForegroundColor Cyan
  _row 'codex exec "..."' 'run one task non-interactively'
  _row 'codex review' 'review local changes non-interactively'
  _row 'codex resume --last' 'continue the most recent session'
  _row 'codex -C path' 'set the working root'
  _row 'codex --search' 'enable live web search for a session'
  _row 'codex update' 'upgrade the CLI'
  Write-Host ''

  Write-Host 'Prompt pattern' -ForegroundColor Cyan
  _row 'Goal' 'state the outcome, not just the file to edit'
  _row 'Constraints' 'compatibility, scope, and behavior to preserve'
  _row 'Acceptance checks' 'tests, lint, build, or exact expected output'
  _row 'Relevant paths / errors' 'include files and unedited command output'
  Write-Host ''

  Write-Host 'WSL paths' -ForegroundColor Cyan
  _row '/mnt/c/Users/rjh/workstation' 'workstation root (left pane CWD)'
  _row '.../dotfiles' 'configs, scripts, wezterm'
  _row '~/.codex/config.toml' 'Codex configuration'
  _row '~/.codex/skills/' 'installed personal skills'
  Write-Host ''

  Write-Host 'Auth & diagnostics' -ForegroundColor Cyan
  _row 'codex login status' 'show current authentication state'
  _row 'codex login' 'authenticate or re-authenticate'
  _row 'codex doctor' 'diagnose configuration and runtime issues'
  _row 'codex features list' 'inspect feature flags'
  Write-Host ''

  Write-Host 'Tab workflow' -ForegroundColor Cyan
  Write-Host '  Claude tab  -> deep planning' -ForegroundColor DarkGray
  Write-Host '  Grok tab    -> research and second opinions' -ForegroundColor DarkGray
  Write-Host '  Codex tab   -> implement, test, review' -ForegroundColor DarkGray
  Write-Host '  Vibe tab    -> Mistral agent, agents, skills' -ForegroundColor DarkGray
  Write-Host '  Git tab     -> inspect, commit, push' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host 'CLI help: codex --help | command help: codex <command> --help' -ForegroundColor DarkCyan
  Write-Host ''
}
]]

M.grok_helper_cmd = [[
Clear-Host
& {
  function _row($cmd, $desc) {
    Write-Host '  ' -NoNewline
    Write-Host $cmd -NoNewline -ForegroundColor Yellow
    Write-Host ('  ' + $desc) -ForegroundColor DarkGray
  }
  $wslDistro = ']]
  .. distro.wsl_distro
  .. [['
  $grokVer = (wsl.exe -d $wslDistro bash -lc 'grok --version 2>/dev/null' 2>$null)
  if ($grokVer) { $grokVer = $grokVer.Trim() } else { $grokVer = '' }
  $authOk = (wsl.exe -d $wslDistro bash -lc 'test -f ~/.grok/auth.json && echo ok || echo missing' 2>$null)
  if ($authOk) { $authOk = $authOk.Trim() } else { $authOk = 'unavailable' }

  Write-Host 'Grok - WSL quick sheet' -ForegroundColor Magenta
  Write-Host 'Agent + web research; fast second opinions.' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host ' Status' -ForegroundColor Cyan
  Write-Host '  Version: ' -NoNewline -ForegroundColor White
  if ($grokVer) {
    Write-Host $grokVer -ForegroundColor Green
  } else {
    Write-Host 'not installed' -ForegroundColor DarkGray
  }
  Write-Host '  Auth:    ' -NoNewline -ForegroundColor White
  if ($authOk -eq 'ok') {
    Write-Host 'ok' -ForegroundColor Green
  } elseif ($authOk -eq 'missing') {
    Write-Host 'missing (browser login on first grok run)' -ForegroundColor Yellow
  } else {
    Write-Host 'unavailable' -ForegroundColor DarkGray
  }
  Write-Host ''

  Write-Host 'When to start here' -ForegroundColor Cyan
  _row 'Research before you build' 'API changes, lib picks, breaking changes'
  _row 'Second opinion' 'sanity-check output from Claude tab'
  _row 'One-shot from shell' 'grok -p "..." without a full session'
  _row 'Office / docs tasks' 'docx, pptx, xlsx skills in ~/.grok/skills/'
  Write-Host ''

  Write-Host 'In-session' -ForegroundColor Cyan
  _row '/plan' 'design before code'
  _row '/compact' 'shrink long history'
  _row '/resume' 'pick up a previous session'
  _row '/skills' 'browse installed skills'
  _row '/context' 'context window usage'
  _row 'Shift+Tab' 'cycle Normal -> Plan -> YOLO'
  Write-Host ''

  Write-Host 'Keys worth knowing' -ForegroundColor Cyan
  _row 'Ctrl+C' 'cancel running tool'
  _row 'y' 'copy selected block (vim mode)'
  _row 'Shift+L / Shift+H' 'jump between turns'
  _row '/vim-mode' 'toggle vim scrollback bindings'
  Write-Host ''

  Write-Host 'Headless / scripting' -ForegroundColor Cyan
  _row 'grok -p "..."' 'one-shot; exits when done'
  _row 'grok -c' 'continue last session in this dir'
  _row 'grok -p "..." --cwd path' 'run against a specific directory'
  _row 'grok -p "..." --yolo' 'auto-approve tool runs'
  _row 'grok update' 'upgrade the CLI'
  Write-Host ''

  Write-Host 'WSL paths' -ForegroundColor Cyan
  _row '/mnt/c/Users/rjh/workstation' 'workstation root (left pane CWD)'
  _row '.../dotfiles' 'configs, scripts, wezterm'
  _row '~/.grok/config.toml' 'Grok config'
  _row '~/.grok/docs/user-guide/' 'full docs'
  Write-Host ''

  Write-Host 'Auth & fixes' -ForegroundColor Cyan
  _row 'First run' 'browser login -> ~/.grok/auth.json'
  _row 'Re-auth' 'delete auth.json, run grok again'
  _row '/terminal-setup' 'clipboard / terminal quirks in session'
  Write-Host ''

  Write-Host 'Tab workflow' -ForegroundColor Cyan
  Write-Host '  Claude tab  -> deep planning' -ForegroundColor DarkGray
  Write-Host '  Grok tab    -> research, /plan, one-shots' -ForegroundColor DarkGray
  Write-Host '  Codex tab   -> implement + test' -ForegroundColor DarkGray
  Write-Host '  Vibe tab    -> Mistral agent, agents, skills' -ForegroundColor DarkGray
  Write-Host '  Git tab     -> commit checklist' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host 'Full slash commands: ~/.grok/docs/user-guide/04-slash-commands.md' -ForegroundColor DarkCyan
  Write-Host ''
}
]]

M.vibe_helper_cmd = [[
Clear-Host
& {
  function _row($cmd, $desc) {
    Write-Host '  ' -NoNewline
    Write-Host $cmd -NoNewline -ForegroundColor Yellow
    Write-Host ('  ' + $desc) -ForegroundColor DarkGray
  }
  $wslDistro = ']]
  .. distro.wsl_distro
  .. [['
  $vibeVer = (wsl.exe -d $wslDistro bash -lc 'vibe --version 2>/dev/null' 2>$null)
  if ($vibeVer) { $vibeVer = $vibeVer.Trim() } else { $vibeVer = '' }
  $authOk = (wsl.exe -d $wslDistro bash -lc 'test -f ~/.vibe/.env && grep -q "^MISTRAL_API_KEY=" ~/.vibe/.env && echo ok || echo missing' 2>$null)
  if ($authOk) { $authOk = $authOk.Trim() } else { $authOk = 'unavailable' }

  Write-Host 'Vibe - WSL quick sheet' -ForegroundColor Magenta
  Write-Host 'Mistral coding agent; tools, agents, skills, MCP, and connectors.' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host ' Status' -ForegroundColor Cyan
  Write-Host '  Version: ' -NoNewline -ForegroundColor White
  if ($vibeVer) {
    Write-Host $vibeVer -ForegroundColor Green
  } else {
    Write-Host 'not installed' -ForegroundColor DarkGray
  }
  Write-Host '  Auth:    ' -NoNewline -ForegroundColor White
  if ($authOk -eq 'ok') {
    Write-Host 'ok' -ForegroundColor Green
  } elseif ($authOk -eq 'missing') {
    Write-Host 'missing (run vibe --setup in left pane)' -ForegroundColor Yellow
  } else {
    Write-Host 'unavailable' -ForegroundColor DarkGray
  }
  Write-Host ''

  Write-Host 'When to start here' -ForegroundColor Cyan
  _row 'Implementation tasks' 'edit files, run commands, verify diffs'
  _row 'Explore & plan first' 'start with --agent plan for read-only analysis'
  _row 'Refactor with guardrails' 'use accept-edits to auto-approve safe changes'
  _row 'Delegate exploration' 'task tool spawns explore subagent'
  _row 'Multi-file changes' 'auto-approve for bulk edits you will review'
  Write-Host ''

  Write-Host 'Agent profiles (Shift+Tab in session)' -ForegroundColor Cyan
  _row 'default' 'approve each tool run before execution (safest)'
  _row 'plan' 'read-only exploration and planning (no file changes)'
  _row 'accept-edits' 'auto-approve write_file and edit only'
  _row 'auto-approve' 'approve ALL tools automatically (use with caution)'
  Write-Host '  User agents: ~/.vibe/agents/*.toml | Subagents: delegation-only' -ForegroundColor DarkGray
  Write-Host ''

  Write-Host 'In-session slash commands (type / to see picker)' -ForegroundColor Cyan
  _row '/help' 'show help for current session'
  _row '/config' 'edit config settings interactively'
  _row '/model' 'select active model'
  _row '/thinking' 'select thinking level'
  _row '/reload' 'reload config, agents, skills from disk'
  _row '/clear' 'clear conversation history'
  _row '/copy' 'copy last agent message to clipboard'
  _row '/log' 'show path to current interaction log'
  _row '/debug' 'toggle debug console'
  _row '/compact' 'summarize conversation history'
  _row '/status' 'display agent statistics'
  _row '/resume /continue' 'browse and resume past sessions'
  _row '/rename' 'rename current session'
  _row '/mcp /connectors' 'list available MCP servers and their tools'
  _row '/sessions' 'resume or manage past sessions'
  _row '/exit' 'leave the session'
  Write-Host ''

  Write-Host 'Special inputs' -ForegroundColor Cyan
  _row '@path/to/file' 'attach files; images work on vision models'
  _row '@dir/' 'attach entire directory'
  _row '!cmd' 'run shell command directly, bypass agent'
  Write-Host ''

  Write-Host 'Keyboard shortcuts' -ForegroundColor Cyan
  _row 'Shift+Tab' 'cycle agent profiles'
  _row 'Ctrl+J / Shift+Enter' 'multi-line input'
  _row 'Ctrl+G' 'edit current plan in external editor'
  _row 'Ctrl+O' 'toggle tool output view'
  _row 'Ctrl+T' 'toggle todo list view'
  _row 'Ctrl+C' 'interrupt or clear input; with selection, copy'
  _row 'Ctrl+Y / Ctrl+Shift+C' 'copy current selection'
  _row 'Escape' 'interrupt current operation'
  _row 'Shift+Up / Shift+Down' 'scroll chat up/down'
  _row 'Ctrl+\' 'toggle debug console'
  _row 'Alt+Up / Ctrl+P' 'rewind to previous message'
  _row 'Alt+Down / Ctrl+N' 'move to next rewound message'
  Write-Host ''

  Write-Host 'Headless / scripting' -ForegroundColor Cyan
  _row 'vibe -p "..."' 'one-shot; exits when done'
  _row 'vibe -p "..." --auto-approve' 'approve all tool calls'
  _row 'vibe -p "..." --agent plan' 'read-only planning run'
  _row 'vibe -p "..." --agent <name>' 'use custom agent profile'
  _row 'vibe -p "..." --max-turns N' 'limit conversation turns'
  _row 'vibe -p "..." --max-price X' 'limit spend to X dollars'
  _row 'vibe -c' 'continue latest session in this dir'
  _row 'vibe --resume' 'pick a previous session'
  _row 'vibe --check-upgrade' 'check for CLI updates'
  _row 'vibe --setup' 're-run setup wizard'
  Write-Host ''

  Write-Host 'Skills & customization' -ForegroundColor Cyan
  _row '/skills' 'browse and toggle installed skills'
  _row '~/.vibe/skills/' 'user-level skills (markdown + YAML)'
  _row './.vibe/skills/' 'project-level skills'
  _row 'user-invocable: true' 'expose skill as /skill-name command'
  Write-Host ''

  Write-Host 'MCP & Connectors' -ForegroundColor Cyan
  _row '/mcp' 'list available MCP servers'
  _row '/connectors' 'list connectors and their tools'
  _row '~/.vibe/mcp/' 'MCP server configurations'
  Write-Host ''

  Write-Host 'WSL paths' -ForegroundColor Cyan
  _row '/mnt/c/Users/rjh/workstation' 'workstation root (left pane CWD)'
  _row '.../dotfiles' 'configs, scripts, wezterm'
  _row '~/.vibe/config.toml' 'Vibe configuration'
  _row '~/.vibe/.env' 'Mistral API key (from vibe --setup)'
  _row '~/.vibe/agents/' 'custom agent profiles'
  _row '~/.vibe/skills/' 'personal skills'
  _row '~/.vibe/mcp/' 'MCP server configs'
  Write-Host ''

  Write-Host 'Auth & install' -ForegroundColor Cyan
  _row 'vibe --setup' 'configure API key and exit'
  _row 'curl -LsSf https://mistral.ai/vibe/install.sh | bash' 'install or upgrade CLI'
  _row 'uv tool upgrade mistral-vibe' 'upgrade via uv directly'
  Write-Host ''

  Write-Host 'Tab workflow' -ForegroundColor Cyan
  Write-Host '  Claude tab  -> deep planning, complex reasoning' -ForegroundColor DarkGray
  Write-Host '  Grok tab    -> research, web search, second opinions' -ForegroundColor DarkGray
  Write-Host '  Codex tab   -> implement, test, review code' -ForegroundColor DarkGray
  Write-Host '  Vibe tab    -> Mistral agent: agents, skills, MCP' -ForegroundColor DarkGray
  Write-Host '  Git tab     -> inspect, commit, push' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host 'CLI help: vibe --help | Full docs: https://docs.mistral.ai/vibe/' -ForegroundColor DarkCyan
  Write-Host ''
}
]]

M.git_top_helper_cmd = [[__wezterm_git_track_root(){ __wt_repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; printf '%s\n' "$__wt_repo" > ~/.wezterm-git-current-repo; }; export -f __wezterm_git_track_root >/dev/null 2>&1 || true; __wt_repo="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; printf '%s\n' "$__wt_repo" > ~/.wezterm-git-current-repo; case ":${PROMPT_COMMAND:-}:" in *"__wezterm_git_track_root"*) ;; *) export PROMPT_COMMAND="__wezterm_git_track_root${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;; esac; git status --short --branch; exec bash -il]]

M.git_right_panel_cmd = [[
while ($true) {
  Clear-Host
  Set-Location "$env:USERPROFILE\workstation"
  $wsRoot = "$env:USERPROFILE\workstation"
  $preferredWs = Join-Path $wsRoot "rjh-workspace.code-workspace"
  $wsFile = if (Test-Path -LiteralPath $preferredWs) {
    Get-Item -LiteralPath $preferredWs
  } else {
    Get-ChildItem -LiteralPath $wsRoot -Filter "*.code-workspace" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -First 1
  }
  $wsBase = if ($wsFile) { Split-Path -Parent $wsFile.FullName } else { $wsRoot }
  $workspace = if ($wsFile) { Get-Content -LiteralPath $wsFile.FullName -Raw | ConvertFrom-Json } else { $null }
  $workspaceFolders = if ($workspace) { $workspace.folders | ForEach-Object {
    $name = if ($_.name) { $_.name } else { [System.IO.Path]::GetFileName($_.path) }
    $fullPath = if ([IO.Path]::IsPathRooted($_.path)) { $_.path } else { Join-Path $wsBase $_.path }
    [PSCustomObject]@{
      Name = $name
      FullName = $fullPath
    }
  } } else { @() }

  Write-Host 'Workspace folders:' -ForegroundColor Cyan
  if (-not $workspaceFolders) {
    Write-Host ' No workspace file or folders.' -ForegroundColor Yellow
  } else {
    foreach ($folder in $workspaceFolders) {
      $isRepo = Test-Path (Join-Path $folder.FullName '.git')
      $branch = if ($isRepo) { git -C $folder.FullName rev-parse --abbrev-ref HEAD 2>$null } else { '-' }
      if (-not $branch) { $branch = '?' }
      $dirty = if ($isRepo) { (git -C $folder.FullName status --porcelain 2>$null | Measure-Object).Count } else { 0 }
      $state = if (-not $isRepo) { 'folder' } elseif ($dirty -gt 0) { 'dirty' } else { 'clean' }
      $markers = @()
      if ($isRepo) { $markers += 'git' }
      if (Test-Path (Join-Path $folder.FullName 'package.json')) { $markers += 'node' }
      if (Test-Path (Join-Path $folder.FullName 'pnpm-lock.yaml')) { $markers += 'pnpm' }
      if (Test-Path (Join-Path $folder.FullName 'requirements.txt')) { $markers += 'python' }
      if (Test-Path (Join-Path $folder.FullName 'pyproject.toml')) { $markers += 'pyproject' }
      if (-not $markers) { $markers += 'folder' }

      Write-Host (' - ' + $folder.Name) -NoNewline -ForegroundColor White
      Write-Host (' [' + $branch + '] ') -NoNewline -ForegroundColor DarkGray
      Write-Host ($state + ' ') -NoNewline -ForegroundColor $(if (-not $isRepo) { 'DarkGray' } elseif ($dirty -gt 0) { 'Yellow' } else { 'Green' })
      Write-Host ('(' + ($markers -join ', ') + ')') -ForegroundColor DarkCyan
    }
  }

  Write-Host ''
  Write-Host 'Git - helper-first runbook' -ForegroundColor Magenta
  Write-Host ''
  Write-Host '  1.  git status --short --branch' -ForegroundColor Yellow
  Write-Host '      check branch + pending changes' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host '  2.  sync-dots   (dotfiles only, when clean)' -ForegroundColor Yellow
  Write-Host '      pull/relink before local edits' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host '  3.  git diff' -ForegroundColor Yellow
  Write-Host '      review unstaged changes' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host '  4.  git add <file>   (or git add -A)' -ForegroundColor Yellow
  Write-Host '      stage intended changes only' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host '  5.  git diff --staged' -ForegroundColor Yellow
  Write-Host '      confirm staged commit content' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host '  6.  git commit -m "type(scope): summary"' -ForegroundColor Yellow
  Write-Host '      feat/fix/docs/chore/refactor/style/test' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host '  7.  git push' -ForegroundColor Yellow
  Write-Host '      fallback: git push -u origin HEAD' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host 'Dotfiles shortcut:' -ForegroundColor Cyan
  Write-Host '  save-dots "chore(dotfiles): summary"' -ForegroundColor Yellow
  Write-Host '  stages all, commits, pushes dotfiles' -ForegroundColor DarkGray
  Write-Host ''
  Write-Host 'Undo:' -ForegroundColor Cyan
  Write-Host '  unstage   git restore --staged <file>'
  Write-Host '  discard   git restore <file>'
  Write-Host '  park      git stash push -m "note"'
  Write-Host '  unpause   git stash apply  (then drop)'
  Write-Host ''
  Write-Host 'Refreshes every 10s. Ctrl+C to stop.' -ForegroundColor DarkGray
  Start-Sleep -Seconds 10
}
]]

M.git_live_view_cmd = [[
state_file="$HOME/.wezterm-git-current-repo"
default_repo=]]
  .. spawn.bash_quote(spawn.bash_path(paths.dotfiles))
  .. [[

while true; do
  clear
  repo="$default_repo"
  if [ -f "$state_file" ]; then
    candidate="$(head -n1 "$state_file" 2>/dev/null | tr -d '\r')"
    if [ -n "$candidate" ]; then
      resolved="$(git -C "$candidate" rev-parse --show-toplevel 2>/dev/null)"
      if [ -n "$resolved" ]; then
        repo="$resolved"
      fi
    fi
  fi

  export GIT_PAGER=cat
  if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    repo_name="$(basename "$repo")"
    printf "\033[38;5;45mGit Watch\033[0m  %s [%s]\n\n" "$repo_name" "$branch"
    printf "\033[38;5;81mLegend:\033[0m * commit | / \\ branch/merge lines | (...) refs | M modified | A added | ?? untracked\n\n"
    printf "\033[38;5;81mStatus:\033[0m\n"
    git -c core.pager=cat -C "$repo" status --short --branch
    printf "\n\033[38;5;81mRecent history:\033[0m\n"
    git -c core.pager=cat -c color.ui=always -C "$repo" log --oneline --graph --decorate --all -20
  else
    printf "\033[38;5;45mGit Watch\033[0m\n\n"
    printf "Waiting for a git repo in the top pane.\n"
    printf "Current path: %s\n" "$repo"
  fi

  printf "\n\033[38;5;244mRefreshes every 3s. Change repo in the top pane with cd.\033[0m\n"
  sleep 3
done
]]

return M
