# Workstation layout (overview)

Canonical root pattern: **`$HOME\workstation\`** (author example on this machine: `C:\Users\rjh\workstation\`). The workstation folder **is** the git repo (`github.com/hedglen/workstation`) — everything lives at the root; there are no junctions or nested repos.

## Folder layout

```text
workstation/                       (= the git repo)
├── install.ps1                    bootstrap
├── rjh-workspace.code-workspace   command center (tracked)
├── CLAUDE.md                      Claude Code context (tracked)
├── docs/                          guides and runbook (this tree)
├── notes/                         personal markdown (notes/personal is gitignored)
├── scripts/                       automation + utilities (workstation-health, transcribe, ...)
├── projects/                      media-organizer, ytdl (.venv from install.ps1)
├── mpv-config/                    mpv Lua/conf bundle; install.ps1 junction → tools\mpv\portable_config
├── lib/                           shared installer/health helpers
├── hedglen.github.io/             personal site content (history lives in its own GitHub repo)
└── tools/                         portable tools (gitignored — binaries only)
    ├── mpv/                       canonical mpv binary location
    └── ...
```

## Rules (no drift)

- **Canonical root**: `$HOME\workstation\` — also the repo root.
- **Prefer relative paths** inside docs and scripts where possible.
- **Portable tools**: `$HOME\workstation\tools\` (never tracked).
- **mpv**: binary at **`tools\mpv\`**, config in **`mpv-config\`**; **`install.ps1`** creates a junction from **`tools\mpv\portable_config`** to that folder when appropriate.
- **Python helpers** (`orgmed`, `ytdl`): live under **`projects\`**; profile and installer use that path.

## Compatibility (legacy paths)

```text
C:\Users\rjh\tools  →  C:\Users\rjh\workstation\tools
```

Treat `%USERPROFILE%\tools` as **compatibility only**. New work should use the canonical workstation paths.

## Next

- Runbook: [**workstation-setup.md**](workstation-setup.md)
- Quick health check: `.\scripts\workstation-health.ps1` from `$HOME\workstation`
