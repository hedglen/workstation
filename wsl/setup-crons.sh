#!/usr/bin/env bash
# wsl/setup-crons.sh
# Idempotently installs system cron jobs for this workstation setup.
# Must be run with sudo (or will re-exec itself with sudo).
# Called by dotfiles/install.ps1 during machine bootstrap.

set -euo pipefail

# ── re-exec with sudo if needed ───────────────────────────────────────────────
# Windows interop (cmd.exe) is unavailable to root, so resolve the Windows
# username BEFORE elevating and pass it through the sudo environment.
if [[ $EUID -ne 0 ]]; then
  WIN_USER="${WIN_USER:-$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n' || true)}"
  exec sudo WIN_USER="$WIN_USER" bash "$0" "$@"
fi

# ── resolve the calling user (even when running under sudo) ──────────────────
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo "$USER")}"
WIN_USER="${WIN_USER:-$REAL_USER}"
WIN_HOME="/mnt/c/Users/${WIN_USER}"
REPO="${WIN_HOME}/workstation"
LOG_DIR="${REPO}/scripts/logs"

echo ">> WSL cron setup"
echo "   Linux user : $REAL_USER"
echo "   Win user   : $WIN_USER"
echo "   Repo       : $REPO"

# ── ensure cron runs on WSL boot ─────────────────────────────────────────────
WSL_CONF="/etc/wsl.conf"
CRON_BOOT_LINE="command=service cron start"

if [[ -f "$WSL_CONF" ]] && grep -q "systemd=true" "$WSL_CONF" 2>/dev/null; then
  echo "   OK  systemd enabled — cron will start via systemd"
else
  # Ensure [boot] section exists with cron start command
  if ! grep -q "$CRON_BOOT_LINE" "$WSL_CONF" 2>/dev/null; then
    if ! grep -q "^\[boot\]" "$WSL_CONF" 2>/dev/null; then
      printf '\n[boot]\n%s\n' "$CRON_BOOT_LINE" >> "$WSL_CONF"
    else
      sed -i "/^\[boot\]/a $CRON_BOOT_LINE" "$WSL_CONF"
    fi
    echo "   OK  added cron boot command to $WSL_CONF"
  else
    echo "   --  cron boot command already in $WSL_CONF"
  fi
  # Start cron now if not running
  if ! service cron status &>/dev/null; then
    service cron start && echo "   OK  cron service started"
  else
    echo "   --  cron already running"
  fi
fi

# ── install cron jobs ─────────────────────────────────────────────────────────
mkdir -p "$LOG_DIR"

install_cron_job() {
  local name="$1" schedule="$2" command="$3"
  local cron_file="/etc/cron.d/${name}"

  local entry="${schedule} ${REAL_USER} ${command}"
  local header="# Managed by dotfiles/wsl/setup-crons.sh — do not edit manually"

  if [[ -f "$cron_file" ]] && grep -qF "$command" "$cron_file" 2>/dev/null; then
    echo "   --  $name already installed"
    return
  fi

  cat > "$cron_file" <<EOF
$header
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

$entry
EOF
  chmod 644 "$cron_file"
  echo "   OK  installed /etc/cron.d/$name"
}

SCRIPT="${REPO}/scripts/organize-downloads.sh"
LOG="${LOG_DIR}/organize-downloads.log"

install_cron_job \
  "dotfiles-organize-downloads" \
  "0 2 * * 0" \
  "bash \"${SCRIPT}\" --run >> \"${LOG}\" 2>&1"

echo ""
echo "   Cron jobs installed. They will fire on schedule while WSL is running."
echo "   Logs: $LOG_DIR"
echo ""
