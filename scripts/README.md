# Scripts

Utility scripts for this workstation. The repo holds the small tools that do not belong in a single app repo but still need to be tracked, documented, and runnable from a clean machine.

## Layout (this folder only)

Everything below lives under **`scripts/`**. For **`autohotkey/`**, **`powershell/`**, **`vscode/`**, **`projects/`**, and the rest of the repo, see the tree in the root **[`README.md`](../README.md#-whats-in-here)**.

- **`python/`** — cross-platform CLI helpers
- **`workstation-health.ps1`** — layout, tooling, and installer dry-runs
- **`transcribe.py`** / **`transcribe.ps1`** — transcription helpers
- **`video-ocr-translate.py`** / **`.ps1`**, **`organize_media*.ps1`**, **`media-rename-downloads.ps1`** — media / one-off operational scripts

## Workstation Health Check

Run this from PowerShell:

```powershell
pwsh -File "$HOME\workstation\scripts\workstation-health.ps1"
```

What it checks:

- canonical `$HOME\workstation` layout
- key Windows tools on `PATH`
- dry-run safety for `install.ps1`
- dry-run safety for `mpv-config/install.ps1` when present
- WezTerm helper scripts (`wezterm/wsl-helper.sh`)
- presence of important linked config files
- dirty git repos across the main workstation repos

For more detail:

```powershell
pwsh -File "$HOME\workstation\scripts\workstation-health.ps1" -Verbose
```

## Repo Hygiene

Generated Python cache files are ignored through `.gitignore`.

If you already have stale cache folders locally, remove them once:

```powershell
Remove-Item -Recurse -Force "$HOME\workstation\scripts\python\__pycache__"
```
