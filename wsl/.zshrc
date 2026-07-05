export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)

source "$ZSH/oh-my-zsh.sh"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"

if [ -z "${WINDOWS_HOME_WSL:-}" ]; then
  _win_home="$(powershell.exe -NoProfile -Command '$env:USERPROFILE' 2>/dev/null | tr -d '\r')"
  if [ -n "$_win_home" ]; then
    export WINDOWS_HOME_WSL="$(wslpath "$_win_home")"
  else
    export WINDOWS_HOME_WSL="/mnt/c/Users/rjh"
  fi
  unset _win_home
fi

export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
mkdir -p "$NPM_CONFIG_PREFIX"
export PATH="$NPM_CONFIG_PREFIX/bin:$HOME/.local/bin:$PATH"
export WORKSTATION="${WORKSTATION:-$WINDOWS_HOME_WSL/workstation}"

dl() {
  yt-dlp \
    --cookies-from-browser "chrome:${WINDOWS_HOME_WSL}/AppData/Local/Google/Chrome/User Data" \
    -o "/mnt/r/Media/x/dl/%(title)s.%(ext)s" \
    "$@"
}

claude() {
  cd "$WORKSTATION" && command claude "$@"
}

codex() {
  cd "$WORKSTATION" && command codex "$@"
}

grok() {
  cd "$WORKSTATION" && command grok "$@"
}

if command -v fdfind >/dev/null 2>&1; then
  alias fd='fdfind'
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v wslview >/dev/null 2>&1; then
  export BROWSER=wslview
fi
