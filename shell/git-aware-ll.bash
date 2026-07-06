# Git-aware ll for Git Bash — colors subdirectory names that are git repos:
#   green  = clean (empty porcelain)
#   yellow = dirty
# Matches WezTerm coding/git panel logic (git -C dir status --porcelain).
#
# Install: add to ~/.bashrc (or ~/.bash_profile):
#   [[ -f ~/workstation/shell/git-aware-ll.bash ]] && . ~/workstation/shell/git-aware-ll.bash

_ll_git_repo_color_line() {
  local line name c r=$'\033[0m'
  line=$1
  case $line in
    d*) ;;
    *) printf '%s\n' "$line"; return 0 ;;
  esac
  name=$(printf '%s' "$line" | awk '{print $NF}')
  case $name in
    .|..) printf '%s\n' "$line"; return 0 ;;
  esac
  if [[ ! -e $name/.git ]]; then
    printf '%s\n' "$line"
    return 0
  fi
  if [[ -n "$(git -C "$name" status --porcelain 2>/dev/null)" ]]; then
    c=$'\033[33m'
  else
    c=$'\033[32m'
  fi
  if [[ -t 1 ]]; then
    printf '%s\n' "${line/%$name/${c}${name}${r}}"
  else
    printf '%s\n' "$line"
  fi
}

_ll_git_colored_ls_la() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    case $line in
      total*) printf '%s\n' "$line"; continue ;;
    esac
    _ll_git_repo_color_line "$line"
  done < <(command ls -la "$@")
}

# Replace ll only if it is still a simple alias to ls (common in Git for Windows).
if alias ll &>/dev/null; then
  unalias ll 2>/dev/null || true
fi

ll() {
  if [[ $# -gt 0 ]]; then
    command ls -la "$@"
    return
  fi
  _ll_git_colored_ls_la
}
