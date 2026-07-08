# Hedglen Workspace - Claude Code Context

## Who I Am

- GitHub: **hedglen**
- OS: Windows 11 Home
- Shell preference: PowerShell (scripts), Bash (Claude Code sessions)

## Workspace Structure

`C:\Users\rjh\workstation\` IS the git repo (`github.com/hedglen/workstation`) — no nesting, no junctions.

```text
C:\Users\rjh\workstation\             # repo root
├── docs/, notes/, scripts/, projects/, mpv-config/, apps/, lib/, wezterm/, wsl/, ...
├── tools/                            # Portable tools (gitignored — binaries only, not tracked)
├── notes/personal/                   # gitignored — personal notes never reach the public remote
├── hedglen.github.io/                # Personal site (static HTML, plain content — separate GitHub repo)
└── CLAUDE.md, README.md, install.ps1, rjh-workspace.code-workspace, ...
```

## Key Projects

| Repo                | Type   | Stack               | Notes                                                                                                                                                                      |
|---------------------|--------|---------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `workstation`       | config | PowerShell, JSON   | Main Windows config & automation (this repo); **mpv-config/** for mpv (Lua, HDR, shaders)                                                                                 |
| `hedglen.github.io` | site   | HTML/CSS/JS        | Personal site; folded in as plain content (no `.git` of its own) — its real history/remote is `github.com/hedglen/hedglen.github.io`; to push changes there, edit in a separate clone of that repo |

## MCP Integrations

- **Gmail** - email management
- **Google Calendar** - scheduling

## Preferences & Conventions

- Commits: imperative mood, no prefix (e.g. "Add print styles", "Update contact email")
- Always review `git diff` before committing
- Push manually - do not auto-push unless asked
- Editors: **Zed** for any plain text editing (`edit` helper, `$env:EDITOR`, git commit editor); **Cursor** for workspace-level work in this repo (`work` opens `rjh-workspace.code-workspace`)
- Keep READMEs updated when making significant changes
- AHK lives in `autohotkey/main.ahk` - launched via registry Run key set by `install.ps1`

## Common Starting Points

**Workspace root (= repo):**

```text
cd C:\Users\rjh\workstation
```

**MPV config:**

```text
cd C:\Users\rjh\workstation\mpv-config
```

**Portable tools:**

```text
cd C:\Users\rjh\workstation\tools
```

## Canonical Path Rules

- Canonical root is always `C:\Users\rjh\workstation\` — it is the repo root.
- New docs/scripts should prefer **relative paths**.
- `%USERPROFILE%\tools` may exist as a **compatibility junction** to `C:\Users\rjh\workstation\tools` - do not use it as the "real" path in new work.
