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

M.coding_helper_cmd = [[
Clear-Host
& {
  function _cliRow($cmd, $desc) {
    Write-Host '  ' -NoNewline
    Write-Host $cmd -NoNewline -ForegroundColor Yellow
    Write-Host ('  ' + $desc) -ForegroundColor DarkGray
  }
  Write-Host 'Coding - CLI quick reference' -ForegroundColor Magenta
  Write-Host 'Most tools from Scoop. Git tab for repo status; WSL right pane for gh cheat sheet.' -ForegroundColor DarkGray
  Write-Host ''

  Write-Host 'Listing' -ForegroundColor Cyan
  _cliRow 'll / la' 'Get-ChildItem (pwsh profile aliases)'
  _cliRow 'eza -la' 'colorized long listing'
  _cliRow 'eza -la --git' 'git column when cwd is inside one repo'
  Write-Host ''

  Write-Host 'Find and pick' -ForegroundColor Cyan
  _cliRow 'rg pattern' 'ripgrep: search file contents'
  _cliRow 'rg -l pattern' 'only filenames with matches'
  _cliRow 'fd name' 'find files by path pattern (respects .gitignore)'
  _cliRow 'fzf' 'fuzzy picker; pipe lines in (e.g. fd | fzf)'
  Write-Host ''

  Write-Host 'View and diffs' -ForegroundColor Cyan
  _cliRow 'bat file' 'syntax-highlighted file view'
  _cliRow 'less file' 'plain pager'
  _cliRow 'git diff' 'delta pager (configured in gitconfig); n/N jump files, q quits'
  Write-Host ''

  Write-Host 'Data and media' -ForegroundColor Cyan
  _cliRow 'jq' 'query JSON (.key, map, select; stdin = JSON text)'
  _cliRow 'exiftool file' 'read/write media metadata (dates, tags, codecs)'
  Write-Host ''

  Write-Host 'Learn' -ForegroundColor Cyan
  _cliRow 'tldr cmd' 'practical examples for any CLI tool'
  Write-Host ''

  Write-Host 'Navigate' -ForegroundColor Cyan
  _cliRow 'z / zi' 'zoxide jump (zi = interactive); pwsh and bash'
  Write-Host ''

  Write-Host 'Git and GitHub' -ForegroundColor Cyan
  _cliRow 'lazygit' 'full-screen git TUI'
  _cliRow 'gh' 'GitHub CLI (pr, issue, repo; gh auth login once)'
  _cliRow 'git status -sb' 'short branch + change list'
  Write-Host ''

  Write-Host 'PowerShell profile' -ForegroundColor Cyan
  _cliRow 'reload' 're-source profile.ps1'
  _cliRow 'which name' 'resolve a command to its path'
  _cliRow 'grep pat' 'pipeline: ... | grep pat (Select-String)'
  _cliRow 'touch path' 'create empty file'
  _cliRow 'dots / tools / home' 'cd shortcuts (see profile.ps1)'
  Write-Host ''

  Write-Host 'Docs: dotfiles/docs/workstation-tools.md (full tool map)' -ForegroundColor DarkCyan
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
  Write-Host 'Claude - quick use cases' -ForegroundColor Magenta
  Write-Host 'Best for planning, architecture, and long-form reasoning.' -ForegroundColor DarkGray
  Write-Host ''

  Write-Host 'When to start here' -ForegroundColor Cyan
  _row 'Plan a refactor' 'ask for options + tradeoffs before editing'
  _row 'Review a PR' 'focus on bugs, regressions, and test gaps'
  _row 'Write docs' 'draft README/runbook/checklist content'
  Write-Host ''

  Write-Host 'Prompt patterns' -ForegroundColor Cyan
  _row 'Goal + constraints + files' 'include paths and acceptance criteria'
  _row 'Ask for phased rollout' 'request step-by-step plan before code'
  _row 'Ask for risk checks' 'compatibility, migration, rollback guidance'
  Write-Host ''

  Write-Host 'Hand off to Codex tab when ready to execute edits/tests.' -ForegroundColor DarkCyan
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
  Write-Host 'Codex - execution quick sheet' -ForegroundColor Magenta
  Write-Host 'Best for implementing edits, running checks, and iterating fast.' -ForegroundColor DarkGray
  Write-Host ''

  Write-Host 'Common flow' -ForegroundColor Cyan
  _row 'Implement <task>' 'apply targeted code changes'
  _row 'Run tests/lint for changed files' 'confirm behavior before commit'
  _row 'Show diff + summarize' 'verify what changed and why'
  Write-Host ''

  Write-Host 'Helpful asks' -ForegroundColor Cyan
  _row 'Fix this error' 'paste exact stack trace or command output'
  _row 'Refactor this file safely' 'ask for minimal behavior-preserving edits'
  _row 'Prepare commit message' 'request conventional commit style summary'
  Write-Host ''

  Write-Host 'Use Claude tab for deep planning; use this tab to ship changes.' -ForegroundColor DarkCyan
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
  Write-Host 'Grok - quick use cases' -ForegroundColor Magenta
  Write-Host 'Best for real-time info (X/web search) and fast second opinions.' -ForegroundColor DarkGray
  Write-Host ''

  Write-Host 'When to start here' -ForegroundColor Cyan
  _row 'Current-events lookups' 'library releases, breaking changes, outages'
  _row 'Second opinion' 'sanity-check a plan from the Claude tab'
  _row 'Quick one-shot questions' 'no long session context needed'
  Write-Host ''

  Write-Host 'CLI basics' -ForegroundColor Cyan
  _row 'grok' 'interactive session (login on first run)'
  _row 'grok upgrade' 'update the CLI in place'
  _row '/help in session' 'commands, model switching, settings'
  Write-Host ''

  Write-Host 'Claude tab for deep planning; Codex tab to ship changes.' -ForegroundColor DarkCyan
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
