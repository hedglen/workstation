#!/usr/bin/env bash
# wsl/setup.sh
# Idempotently provisions the WSL side of this dotfiles setup: apt tooling,
# zsh + oh-my-zsh + Powerlevel10k, the tracked shell files, uv, npm global
# prefix, and the claude/codex/grok CLIs the WezTerm tabs expect.
# Run as the normal WSL user (uses sudo only where needed).
# Called by dotfiles/install.ps1 during machine bootstrap; safe to re-run.

set -uo pipefail

step() { echo -e "\n>> $1"; }
ok()   { echo "   OK  $1"; }
skip() { echo "   --  $1"; }
warn() { echo "   !!  $1"; }

if [[ $EUID -eq 0 && -z "${SUDO_USER:-}" ]]; then
  warn "Run this as your normal WSL user, not root (it uses sudo where needed)."
  exit 1
fi

# ── resolve the Windows-side dotfiles checkout ────────────────────────────────
WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
WIN_HOME="/mnt/c/Users/${WIN_USER}"
DOTFILES="${WIN_HOME}/workstation/dotfiles"

echo ">> WSL provisioning"
echo "   Linux user : $USER"
echo "   Win user   : $WIN_USER"
echo "   Dotfiles   : $DOTFILES"

if [[ ! -d "$DOTFILES" ]]; then
  warn "Dotfiles checkout not found at $DOTFILES — run dotfiles/install.ps1 on the Windows side first."
  exit 1
fi

# ── apt packages ──────────────────────────────────────────────────────────────
step "apt packages"
APT_PKGS=(
  zsh git curl wget
  ripgrep fd-find fzf jq tmux btop ncdu
  gh neovim pipx zoxide wslu
  ffmpeg python3 python3-pip
  nodejs npm
)
missing=()
for p in "${APT_PKGS[@]}"; do
  dpkg -s "$p" &>/dev/null || missing+=("$p")
done
if ((${#missing[@]})); then
  if sudo apt-get update -y && sudo apt-get install -y "${missing[@]}"; then
    ok "installed: ${missing[*]}"
  else
    warn "apt install failed for: ${missing[*]}"
  fi
else
  skip "all apt packages present"
fi

# ── oh-my-zsh + Powerlevel10k (what the tracked .zshrc expects) ───────────────
step "oh-my-zsh"
if [[ -d "$HOME/.oh-my-zsh" ]]; then
  skip "oh-my-zsh already installed"
else
  if RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
    ok "oh-my-zsh installed"
  else
    warn "oh-my-zsh install failed"
  fi
fi

step "Powerlevel10k"
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [[ -d "$P10K_DIR" ]]; then
  skip "powerlevel10k already installed"
elif git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"; then
  ok "powerlevel10k installed"
else
  warn "powerlevel10k clone failed"
fi

# ── tracked shell files ───────────────────────────────────────────────────────
step "shell dotfiles (.zshrc, .p10k.zsh)"
for f in .zshrc .p10k.zsh; do
  src="$DOTFILES/wsl/$f"
  if [[ ! -f "$src" ]]; then
    warn "missing tracked file: $src"
    continue
  fi
  if [[ -f "$HOME/$f" ]] && cmp -s "$src" "$HOME/$f"; then
    skip "$f up to date"
  else
    cp "$src" "$HOME/$f" && ok "$f copied"
  fi
done

# ── uv (Python tooling; .zshrc puts ~/.local/bin on PATH) ─────────────────────
step "uv"
if command -v uv &>/dev/null || [[ -x "$HOME/.local/bin/uv" ]]; then
  skip "uv already installed"
elif curl -LsSf https://astral.sh/uv/install.sh | sh; then
  ok "uv installed"
else
  warn "uv install failed"
fi

# ── yt-dlp (used by the dl alias) ─────────────────────────────────────────────
step "yt-dlp"
if command -v yt-dlp &>/dev/null || [[ -x "$HOME/.local/bin/yt-dlp" ]]; then
  skip "yt-dlp already installed"
elif pip3 install --user --break-system-packages yt-dlp; then
  ok "yt-dlp installed"
else
  warn "yt-dlp install failed"
fi

# ── npm global prefix (pinned by .zshrc to avoid split-path Codex installs) ───
step "npm global prefix"
export NPM_CONFIG_PREFIX="${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
mkdir -p "$NPM_CONFIG_PREFIX/bin"
ok "~/.npm-global ready"

# ── claude/codex/grok CLIs (the WezTerm AI tabs expect these) ─────────────────
step "Claude Code CLI"
if command -v claude &>/dev/null || [[ -x "$HOME/.local/bin/claude" ]]; then
  skip "claude already installed"
elif curl -fsSL https://claude.ai/install.sh | bash; then
  ok "claude installed"
else
  warn "claude install failed — run: curl -fsSL https://claude.ai/install.sh | bash"
fi

step "Codex CLI"
if command -v codex &>/dev/null || [[ -x "$NPM_CONFIG_PREFIX/bin/codex" ]]; then
  skip "codex already installed"
elif npm install -g @openai/codex; then
  ok "codex installed"
else
  warn "codex install failed — run: npm install -g @openai/codex"
fi

step "Grok CLI"
# Installs to ~/.grok/bin with a symlink in ~/.local/bin (already on PATH via .zshrc)
if command -v grok &>/dev/null || [[ -x "$HOME/.local/bin/grok" ]]; then
  skip "grok already installed"
elif curl -fsSL https://x.ai/cli/install.sh | bash; then
  ok "grok installed"
else
  warn "grok install failed — run: curl -fsSL https://x.ai/cli/install.sh | bash"
fi

# ── default shell ─────────────────────────────────────────────────────────────
step "default shell"
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ "$current_shell" == *zsh ]]; then
  skip "default shell already zsh"
elif sudo chsh -s "$(command -v zsh)" "$USER"; then
  ok "default shell set to zsh"
else
  warn "could not change default shell — run: chsh -s \$(command -v zsh)"
fi

echo ""
echo "   WSL provisioning done. Remaining manual step: gh auth login"
echo ""
