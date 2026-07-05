# Workstation setup (runbook)

Command center for **rebuild, verify, and maintain** the workstation environment.

## Canonical rules (do not drift)

- **Canonical root**: `$HOME\workstation\` (author example: `C:\Users\rjh\workstation\`)
- **Dotfiles is the source of truth** for installed apps and hotkey targets: `dotfiles/apps/winget-packages.json`, `dotfiles/apps/scoop-packages.json`, plus `apps/winget-packages.md` / `apps/scoop-packages.md`. This runbook, **`dotfiles/docs/`**, and AutoHotkey should agree with those lists; anything not in a manifest is **optional / manual** — say so in prose.
- **Prefer relative paths** in docs (e.g. `dotfiles/`, `tools/`). For Python helpers, source of truth is **`dotfiles/projects/`**; **`workstation\projects`** is usually a **junction** to that folder.
- **Absolute paths** only when clarity needs it; prefer `$HOME`-based examples for portability.
- **Compatibility only**: `%USERPROFILE%\tools` may be a **junction** → `$HOME\workstation\tools`. Do not use it in new work except when explaining compatibility.

## Workspace layout (canonical)

```text
workstation/
│
├── rjh-workspace.code-workspace   (command center)
├── WORKSTATION-SETUP.md           (stub → dotfiles/docs/workstation-setup.md)
│
├── dotfiles/                      (configs + docs + notes + scripts + bundled projects)
│   ├── docs/                      guides: workstation-setup, layout, tools, directory-opus
│   ├── notes/                     (personal markdown)
│   ├── scripts/                   (automation + utilities; see dotfiles/scripts/README.md)
│   ├── projects/                  (media-organizer, ytdl - Python venvs from install.ps1)
│   └── mpv-config/                mpv Lua/conf bundle; junction → tools\mpv\portable_config
├── tools/                         (portable tools / utilities)
├── projects/                      (junction → dotfiles\projects when install.ps1 created it)
└── hedglen-profile/               (GitHub profile)

```

**Also:** `workstation\scripts` is normally a **junction** → `dotfiles\scripts` (same installer pattern).

## Fresh machine bootstrap

From PowerShell (Git required first):

```powershell
irm https://raw.githubusercontent.com/hedglen/dotfiles/master/install.ps1 | iex
```

This clones and configures the workspace:

1. `dotfiles` → `workstation/dotfiles`
2. `hedglen-profile` → workspace dir; **`workstation\tools`** created if missing. Junctions **`workstation\scripts`** → **`dotfiles\scripts`** and **`workstation\projects`** → **`dotfiles\projects`** when those paths are unused. Utility scripts: **`dotfiles/scripts/`**. Personal notes: **`dotfiles/notes/`**. Workstation-root docs restored: **`CLAUDE.md`** (from `dotfiles/claude/CLAUDE.md`) and the **`WORKSTATION-SETUP.md`** stub.
3. Apps via winget + Scoop (`dotfiles/apps/winget-packages.json` and `scoop-packages.json`; use **`-NoScoop`** to skip Scoop only), then the **Claude Code CLI** (native installer, auto-updates) if `claude` is missing.
4. Python **`.venv`** setup for **`dotfiles\projects\media-organizer`**, **`dotfiles\projects\ytdl`**, and **`tools\transcribe-env`** (Whisper deps — large download; needs **`uv`** or **`py`** on PATH; skip with **`-NoPythonProjects`** or **`-ConfigsOnly`**).
5. Windows tweaks (admin required)
6. Config symlinks, VS Code + Cursor extensions, fonts, mpv config, AutoHotkey
   - config map lives in **`dotfiles/lib/config-links.ps1`** — the single source used by `install.ps1`, `maintenance/update.ps1`, and the health check
   - **Claude Code:** `dotfiles/claude/settings.json` → `~/.claude/settings.json`
   - **mpv:** junction **`tools\mpv\portable_config`** → **`dotfiles\mpv-config`** (when `install.ps1` sets it up)
   - **yt-dlp global CLI:** `dotfiles/projects/ytdl/appdata-config` → `%APPDATA%\yt-dlp\config` (same as [workstation-tools.md](workstation-tools.md))
7. WSL provisioning: **`wsl/setup.sh`** (apt tools, zsh + oh-my-zsh + Powerlevel10k, tracked `.zshrc`/`.p10k.zsh`, uv, claude/codex) and **`wsl/setup-crons.sh`** (cron jobs). If the distro was just registered, launch Ubuntu once to create your user, then re-run `install.ps1`.
8. Startup cleanup policy (auto-enforced by `install.ps1` and `maintenance/update.ps1`)
   - HKCU Run entries removed when present: `AdobeBridge`, `Adobe Acrobat Synchronizer`, `GoogleChromeAutoLaunch_*` (machine-specific hash), `Discord`, `org.whispersystems.signal-desktop`, `WingetUI`, `IDMan`, `LGHUB`
   - Startup shortcut removed when present: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Send to OneNote.lnk`

**Python helpers:** venvs are created by **`install.ps1`** by default. To **repair** manually (e.g. after a bad upgrade), recreate any of them the uv-first way:

```powershell
# media-organizer / ytdl (same pattern)
Set-Location "$HOME\workstation\dotfiles\projects\media-organizer"
uv venv .venv
uv pip install --python .\.venv\Scripts\python.exe -r requirements.txt

# transcribe-env (lives under tools\)
uv venv "$HOME\workstation\tools\transcribe-env"
uv pip install --python "$HOME\workstation\tools\transcribe-env\Scripts\python.exe" -r "$HOME\workstation\dotfiles\scripts\requirements-transcribe.txt"
```

If **`workstation\projects`** is a junction, `Set-Location "$HOME\workstation\projects\media-organizer"` is equivalent.

---

## Quick start

### Open the workspace

```powershell
code "$HOME\workstation\rjh-workspace.code-workspace"
```

### Typical working directories

```powershell
Set-Location "$HOME\workstation"
Set-Location "$HOME\workstation\dotfiles"
Set-Location "$HOME\workstation\projects"   # junction → dotfiles\projects when installer set it up
```

## Compatibility junctions

```text
%USERPROFILE%\tools             →  workstation\tools
workstation\scripts             →  dotfiles\scripts    (when created by install.ps1)
workstation\projects            →  dotfiles\projects   (when created by install.ps1)
```

If a doc or script mentions **`%USERPROFILE%\tools`** only, treat it as **compat** for the tools folder.

## Verification checklist

### Workspace health

- Open `rjh-workspace.code-workspace` and confirm all folders resolve.

### Fast health check (recommended)

```powershell
Set-Location "$HOME\workstation"
.\dotfiles\scripts\workstation-health.ps1
```

Verbose:

```powershell
.\dotfiles\scripts\workstation-health.ps1 -Verbose
```

### Junction health

- Confirm `%USERPROFILE%\tools` resolves into `workstation\tools` (if you use that junction).
- Optionally confirm **`workstation\scripts`** and **`workstation\projects`** point at **`dotfiles\scripts`** and **`dotfiles\projects`**.

### Dry-run installers

```powershell
Set-Location "$HOME\workstation\dotfiles"
.\install.ps1 -DryRun

Set-Location "$HOME\workstation\dotfiles\mpv-config"
.\install.ps1 -DryRun
```

---

**Last updated:** 2026-07-05

