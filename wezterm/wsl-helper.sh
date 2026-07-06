#!/usr/bin/env bash
# WSL tab right pane — printed once, then drops into zsh. Spawned via wezterm.lua wsl_helper_spawn().
cd "$HOME" || exit 1
clear

# ---- Path resolution ----
_win_profile_raw=$(powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('UserProfile')" 2>/dev/null | tr -d '\r')
_win_profile_raw=${_win_profile_raw//$'\r'/}
if [ -z "$_win_profile_raw" ]; then
  _win_profile_raw=$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r')
  _win_profile_raw=${_win_profile_raw//$'\r'/}
fi
_win_base=""
if [ -n "$_win_profile_raw" ]; then
  if command -v wslpath >/dev/null 2>&1; then
    _win_base=$(wslpath -u "$_win_profile_raw" 2>/dev/null)
  fi
  if [ -z "$_win_base" ] && [[ "$_win_profile_raw" =~ ^([A-Za-z]):\\(.*)$ ]]; then
    _dr="${BASH_REMATCH[1],,}"
    _rest="${BASH_REMATCH[2]//\\//}"
    _win_base="/mnt/${_dr}/${_rest}"
  fi
fi
_win_ws=""
_win_ws_warn=""
if [ -n "$_win_base" ]; then
  _win_ws="${_win_base}/workstation"
fi
if [ -z "$_win_ws" ]; then
  _win_ws="/mnt/c/Users/${USER}/workstation"
  _win_ws_warn="1"
fi
_win_projects="${_win_ws}/projects"
_win_repo="${_win_ws}"
_win_scripts="${_win_ws}/scripts"

# ---- Helper function for consistent formatting ----
_row() {
  printf "  \033[33m%-25s\033[0m %s\n" "$1" "$2"
}

_section() {
  printf "\n\033[36m%s\033[0m\n" "$1"
}

_subsection() {
  printf "\033[90m%s\033[0m\n" "$1"
}

# ---- Header ----
printf "\033[35mWSL - General Development Tab\033[0m\n"
printf "\033[90mYour default WSL terminal for direct commands, quick edits, and testing.\033[0m\n"
printf "\033[90mUse this when you don't need an AI agent - or to prep before using one.\033[0m\n"

# ---- Status ----
_section "Status"
printf "  Distro:  \033[37m%s\033[0m\n" "${WSL_DISTRO_NAME:-Ubuntu}"
printf "  Kernel:  \033[37m%s\033[0m\n" "$(uname -r)"
if command -v zsh >/dev/null 2>&1; then
  printf "  Shell:   \033[37m%s\033[0m\n" "$(command -v zsh)"
else
  printf "  Shell:   \033[37m%s\033[0m\n" "$(command -v bash)"
fi
printf "  Home:    \033[37m%s\033[0m\n" "$HOME"
printf "  Mount:   \033[37m%s\033[0m\n" "$_win_ws"
if [ -n "$_win_ws_warn" ]; then
  printf "  \033[33mMount paths: guessed from USER; may be inaccurate\033[0m\n"
fi

# ---- When to start here ----
_section "When to start here"
_row "Quick file edits" "vim/nano/sed without spawning an agent"
_row "Run one-off commands" "grep, find, curl, build steps"
_row "Test AI tool output" "verify changes before accepting in AI tabs"
_row "Git operations" "status, diff, commit, push (or use Git tab)"
_row "Explore codebase" "rg, fd, eza, bat for fast navigation"
_row "Prep for AI tabs" "gather context, files, logs to reference"
_row "Manual debugging" "logs, tail, journalctl, strace"
_row "System tasks" "apt, pip, npm, cargo install"

# ---- Tab workflow ----
_section "Tab workflow"
printf "  \033[37mThis tab\033[0m         -> general shell, quick tasks, prep work\n"
printf "  \033[37mGrok tab\033[0m       -> research, second opinions, web search\n"
printf "  \033[37mClaude tab\033[0m     -> deep planning, complex reasoning\n"
printf "  \033[37mCodex tab\033[0m      -> implement, test, review code\n"
printf "  \033[37mVibe tab\033[0m       -> Mistral agent: tools, agents, MCP\n"
printf "  \033[37mGit tab\033[0m        -> commit checklists, git TUI\n"
printf "  \033[37mToolbelt tab\033[0m   -> scoop tools cheat sheet\n"

# ---- Quick jump ----
_section "Quick jump"
printf "  \033[37mcd ~\033[0m                      # WSL home\n"
printf "  \033[37mcd %s\033[0m       # workstation root\n" "$_win_ws"
printf "  \033[37mcd %s\033[0m      # projects directory\n" "$_win_projects"
printf "  \033[37mcd %s\033[0m     # repo root (configs)\n" "$_win_repo"
printf "  \033[37mcd %s\033[0m    # custom scripts\n" "$_win_scripts"
printf "\n"
printf "  \033[37mworkstation\033[0m    -> %s\n" "$_win_ws"
printf "  \033[37mprojects\033[0m       -> %s\n" "$_win_projects"
printf "  \033[37mscripts\033[0m        -> %s\n" "$_win_scripts"

# ---- Installed tooling ----
_section "Installed tooling"

# Check for git
if command -v git >/dev/null 2>&1; then
  _git_ver=$(git --version 2>/dev/null | sed 's/git version //')
  printf "  \033[32mgit\033[0m:       %s\n" "$_git_ver"
else
  printf "  \033[31mgit\033[0m:       missing\n"
fi

# Check for node
if command -v node >/dev/null 2>&1; then
  _node_ver=$(node -v 2>/dev/null)
  printf "  \033[32mnode\033[0m:      %s\n" "$_node_ver"
else
  printf "  \033[31mnode\033[0m:      missing\n"
fi

# Check for python3
if command -v python3 >/dev/null 2>&1; then
  _py_ver=$(python3 --version 2>&1 | sed 's/Python //')
  printf "  \033[32mpython3\033[0m:    %s\n" "$_py_ver"
else
  printf "  \033[31mpython3\033[0m:    missing\n"
fi

# Check for uv
if command -v uv >/dev/null 2>&1; then
  _uv_ver=$(uv --version 2>/dev/null)
  printf "  \033[32muv\033[0m:         %s\n" "$_uv_ver"
else
  printf "  \033[90muv\033[0m:         missing\n"
fi

# Check for pnpm
if command -v pnpm >/dev/null 2>&1; then
  _pnpm_ver=$(pnpm --version 2>/dev/null)
  printf "  \033[32mpnpm\033[0m:       %s\n" "$_pnpm_ver"
else
  printf "  \033[90mpnpm\033[0m:       missing\n"
fi

# Check for cargo
if command -v cargo >/dev/null 2>&1; then
  _cargo_ver=$(cargo --version 2>/dev/null | sed 's/cargo //')
  printf "  \033[32mcargo\033[0m:      %s\n" "$_cargo_ver"
else
  printf "  \033[90mcargo\033[0m:      missing\n"
fi

# Check for go
if command -v go >/dev/null 2>&1; then
  _go_ver=$(go version 2>/dev/null | sed 's/go version //')
  printf "  \033[32mgo\033[0m:         %s\n" "$_go_ver"
else
  printf "  \033[90mgo\033[0m:         missing\n"
fi

# ---- Common commands ----
_section "Common commands"

_subsection "Search & navigate"
_row "fd pattern" "find files by name (respects .gitignore)"
_row "rg pattern" "search file contents (ripgrep)"
_row "fzf" "fuzzy finder for history, files, processes"
_row "z dir" "zoxide: jump to frequently used directories"
_row "z -i" "zoxide: interactive directory selection"
_row "eza -la" "modern ls with colors and git status"
_row "tree" "display directory structure"

_subsection "View & edit"
_row "bat file" "cat with syntax highlighting + line numbers"
_row "glow file.md" "render markdown in terminal"
_row "less file" "pager (q=quit, /=search, n/N=navigate)"
_row "vim file" "edit with vim"
_row "nvim file" "edit with neovim"
_row "sd old new file" "find & replace (simpler than sed)"

_subsection "Git"
_row "git status" "show working tree status"
_row "git diff" "show unstaged changes (with delta pager)"
_row "git log -p" "show commit history with diffs"
_row "git add -p" "interactive staging"
_row "lazygit" "full-screen git TUI"
_row "gh" "GitHub CLI (pr, issue, repo)"

_subsection "Process & system"
_row "htop" "interactive process viewer"
_row "btm" "modern htop alternative"
_row "dust" "disk usage visualization"
_row "du -sh *" "directory sizes"
_row "df -h" "filesystem disk space"
_row "free -h" "memory usage"
_row "ps aux | grep pat" "find running processes"
_row "kill -9 pid" "force kill a process"

_subsection "Network"
_row "curl -v url" "HTTP requests with verbose output"
_row "wget url" "download files"
_row "httpie url" "user-friendly HTTP client (http)"
_row "ping host" "test network connectivity"
_row "mtr host" "combined ping + traceroute"
_row "nc -zv host port" "test TCP connection"
_row "ssh user@host" "connect to remote server"

_subsection "Files & compression"
_row "tar -czvf file.tar.gz dir/" "create gzipped tarball"
_row "tar -xzvf file.tar.gz" "extract gzipped tarball"
_row "zip -r file.zip dir/" "create zip archive"
_row "unzip file.zip" "extract zip archive"
_row "xz -d file.xz" "decompress xz file"
_row "jq '.key' file.json" "query JSON files"
_row "yq '.key' file.yaml" "query YAML files"

# ---- Package managers ----
_section "Package managers"

_subsection "System (apt)"
_row "apt update" "update package lists"
_row "apt upgrade" "upgrade installed packages"
_row "apt install pkg" "install a package"
_row "apt search term" "search for packages"
_row "apt remove pkg" "remove a package"

_subsection "Python"
_row "pip install pkg" "install Python package"
_row "pip install -r requirements.txt" "install from requirements"
_row "python -m venv venv" "create virtual environment"
_row "source venv/bin/activate" "activate virtual environment"
_row "uv pip install pkg" "faster pip via uv"
_row "uv pip compile" "generate requirements.txt"

_subsection "Node.js"
_row "npm install" "install dependencies"
_row "npm install -g pkg" "install globally"
_row "pnpm install" "faster npm via pnpm"
_row "pnpm add pkg" "add dependency"
_row "node script.js" "run JavaScript file"
_row "npx cmd" "run node command"

_subsection "Rust"
_row "cargo build" "build Rust project"
_row "cargo run" "build and run"
_row "cargo test" "run tests"
_row "cargo check" "quick type check"
_row "cargo add dep" "add dependency"

# ---- AI CLI tools ----
_section "AI CLI tools (use dedicated tabs for full sessions)"

_subsection "Quick one-shots from here"
_row "grok -p 'question'" "Grok: quick answer, no session"
_row "claude -p 'task'" "Claude: one-shot task"
_row "codex -p 'task'" "Codex: one-shot implementation"
_row "vibe -p 'task'" "Vibe: one-shot with Mistral"

_subsection "Version & auth checks"
if command -v grok >/dev/null 2>&1; then
  _grok_ver=$(grok --version 2>/dev/null)
  printf "  \033[32mgrok\033[0m:       %s\n" "$_grok_ver"
else
  printf "  \033[90mgrok\033[0m:       not installed in WSL\n"
fi
if command -v claude >/dev/null 2>&1; then
  _claude_ver=$(claude --version 2>/dev/null)
  printf "  \033[32mclaude\033[0m:     %s\n" "$_claude_ver"
else
  printf "  \033[90mclaude\033[0m:     not installed in WSL\n"
fi
if command -v codex >/dev/null 2>&1; then
  _codex_ver=$(codex --version 2>/dev/null)
  printf "  \033[32mcodex\033[0m:      %s\n" "$_codex_ver"
else
  printf "  \033[90mcodex\033[0m:      not installed in WSL\n"
fi
if command -v vibe >/dev/null 2>&1; then
  _vibe_ver=$(vibe --version 2>/dev/null)
  printf "  \033[32mvibe\033[0m:       %s\n" "$_vibe_ver"
else
  printf "  \033[90mvibe\033[0m:       not installed in WSL\n"
fi
printf "\n"
_row "grok auth status" "check Grok authentication"
_row "claude auth status" "check Claude authentication"
_row "codex login status" "check Codex authentication"
_row "vibe --setup" "configure Vibe API key"

# ---- Workspace info ----
_section "Workspace info"
printf "  Left pane CWD: \033[37m%s\033[0m\n" "$_win_ws"
printf "  Projects:      \033[37m%s\033[0m\n" "$_win_projects"
printf "  Repo:          \033[37m%s\033[0m\n" "$_win_repo"
printf "  Scripts:       \033[37m%s\033[0m\n" "$_win_scripts"

# ---- Tips ----
_section "Tips"
printf "  \033[90mCtrl+Shift+C\033[0m     Copy selected text\n"
printf "  \033[90mCtrl+Shift+V\033[0m     Paste from clipboard\n"
printf "  \033[90mCtrl+Shift+F\033[0m     Search scrollback\n"
printf "  \033[90mAlt+Click\033[0m       Select text in rectangular mode\n"
printf "  \033[90mCtrl+Tab\033[0m       Cycle through tabs\n"
printf "  \033[90mCtrl+Number\033[0m     Switch to specific tab\n"
printf "\n"
printf "  \033[90mType 'reload' in left pane to re-source shell profile\n"
printf "  \033[90mUse 'workstation', 'projects', 'scripts' for quick cd\n"

# ---- Drop to shell ----
printf "\n"
if command -v zsh >/dev/null 2>&1; then
  exec zsh -il
fi
exec bash -il
