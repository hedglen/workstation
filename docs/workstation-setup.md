# Workstation setup (runbook)

Command center for **rebuild, verify, and maintain** the workstation environment.

## Canonical rules (do not drift)

- **Canonical root**: `$HOME\workstation\` (author example: `C:\Users\rjh\workstation\`) — the folder **is** the git repo (`github.com/hedglen/workstation`). No junctions, no nesting.
- **The manifests are the source of truth** for installed apps and hotkey targets: `apps/winget-packages.json`, `apps/scoop-packages.json`, plus `apps/winget-packages.md` / `apps/scoop-packages.md`. This runbook, **`docs/`**, and AutoHotkey should agree with those lists; anything not in a manifest is **optional / manual** — say so in prose.
- **Prefer relative paths** in docs (e.g. `scripts/`, `tools/`). Python helpers live under **`projects/`**.
- **Absolute paths** only when clarity needs it; prefer `$HOME`-based examples for portability.
- **Compatibility only**: `%USERPROFILE%\tools` may be a **junction** → `$HOME\workstation\tools`. Do not use it in new work except when explaining compatibility.

## Workspace layout (canonical)

```text
workstation/                       (= the git repo)
├── install.ps1                    bootstrap
├── rjh-workspace.code-workspace   command center (tracked)
├── CLAUDE.md                      Claude Code context (tracked)
├── docs/                          guides: workstation-setup, layout, tools, directory-opus
├── notes/                         personal markdown (notes/personal gitignored)
├── scripts/                       automation + utilities; see scripts/README.md
├── projects/                      media-organizer, ytdl - Python venvs from install.ps1
├── mpv-config/                    mpv Lua/conf bundle; junction → tools\mpv\portable_config
├── lib/                           shared installer/health helpers
├── hedglen.github.io/             personal site content
└── tools/                         portable tools (gitignored — binaries only)
```

## Fresh machine bootstrap

From PowerShell (Git required first):

```powershell
irm https://raw.githubusercontent.com/hedglen/workstation/master/install.ps1 | iex
```

This hydrates and configures the workspace:

1. Repo → `$HOME\workstation` directly (`git init` + fetch + checkout — works in a non-empty folder)
2. Apps via winget + Scoop (`apps/winget-packages.json` and `scoop-packages.json`; use **`-NoScoop`** to skip Scoop only), then the **Claude Code CLI** (native installer, auto-updates) if `claude` is missing.
3. Python **`.venv`** setup for **`projects\media-organizer`**, **`projects\ytdl`**, and **`tools\transcribe-env`** (Whisper deps — large download; needs **`uv`** or **`py`** on PATH; skip with **`-NoPythonProjects`** or **`-ConfigsOnly`**).
4. Windows tweaks (admin required)
5. Config symlinks, VS Code + Cursor extensions, fonts, mpv config, AutoHotkey
   - config map lives in **`lib/config-links.ps1`** — the single source used by `install.ps1`, `maintenance/update.ps1`, and the health check
   - **Claude Code:** `claude/settings.json` → `~/.claude/settings.json`
   - **mpv:** junction **`tools\mpv\portable_config`** → **`mpv-config\`** (when `install.ps1` sets it up)
   - **yt-dlp global CLI:** `projects/ytdl/appdata-config` → `%APPDATA%\yt-dlp\config` (same as [workstation-tools.md](workstation-tools.md))
6. WSL provisioning: **`wsl/setup.sh`** (apt tools, zsh + oh-my-zsh + Powerlevel10k, tracked `.zshrc`/`.p10k.zsh`, uv, claude/codex/grok/vibe) and **`wsl/setup-crons.sh`** (cron jobs). If the distro was just registered, launch Ubuntu once to create your user, then re-run `install.ps1`.
7. Startup cleanup policy (auto-enforced by `install.ps1` and `maintenance/update.ps1`)
   - HKCU Run entries removed when present: `AdobeBridge`, `Adobe Acrobat Synchronizer`, `GoogleChromeAutoLaunch_*` (machine-specific hash), `Discord`, `org.whispersystems.signal-desktop`, `WingetUI`, `IDMan`, `LGHUB`
   - Startup shortcut removed when present: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Send to OneNote.lnk`

**Python helpers:** venvs are created by **`install.ps1`** by default. To **repair** manually (e.g. after a bad upgrade), recreate any of them the uv-first way:

```powershell
# media-organizer / ytdl (same pattern)
Set-Location "$HOME\workstation\projects\media-organizer"
uv venv .venv
uv pip install --python .\.venv\Scripts\python.exe -r requirements.txt

# transcribe-env (lives under tools\)
uv venv "$HOME\workstation\tools\transcribe-env"
uv pip install --python "$HOME\workstation\tools\transcribe-env\Scripts\python.exe" -r "$HOME\workstation\scripts\requirements-transcribe.txt"
```

---

## Quick start

### Open the workspace

```powershell
code "$HOME\workstation\rjh-workspace.code-workspace"
```

### Typical working directories

```powershell
Set-Location "$HOME\workstation"             # repo root — everything is here
Set-Location "$HOME\workstation\projects"
Set-Location "$HOME\workstation\scripts"
```

## Compatibility junctions

```text
%USERPROFILE%\tools             →  workstation\tools
```

If a doc or script mentions **`%USERPROFILE%\tools`** only, treat it as **compat** for the tools folder.

## Verification checklist

### Workspace health

- Open `rjh-workspace.code-workspace` and confirm all folders resolve.

### Fast health check (recommended)

```powershell
Set-Location "$HOME\workstation"
.\scripts\workstation-health.ps1
```

Verbose:

```powershell
.\scripts\workstation-health.ps1 -Verbose
```

### Junction health

- Confirm `%USERPROFILE%\tools` resolves into `workstation\tools` (if you use that junction).

### Dry-run installers

```powershell
Set-Location "$HOME\workstation"
.\install.ps1 -DryRun

Set-Location "$HOME\workstation\mpv-config"
.\install.ps1 -DryRun
```

---

**Last updated:** 2026-07-05

