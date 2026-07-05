# Hedglen Workspace - Claude Code Context

## Who I Am
- GitHub: **hedglen**
- OS: Windows 11 Home
- Shell preference: PowerShell (scripts), Bash (Claude Code sessions)

## Workspace Structure

```
C:\Users\rjh\workstation\
├── rjh-workspace.code-workspace  # Command center workspace file
├── WORKSTATION-SETUP.md          # Stub → dotfiles/docs/workstation-setup.md
├── dotfiles/                     # Config + docs/, notes/, scripts/, projects/, mpv-config/
├── tools/                        # Portable tools (canonical)
├── scripts/                      # Junction → dotfiles\scripts (when install.ps1 created it)
├── projects/                     # Junction → dotfiles\projects (when install.ps1 created it)
└── hedglen-profile/              # GitHub profile README
```

## Key Projects

| Repo | Type | Stack | Notes |
|------|------|-------|-------|
| `dotfiles` | config | PowerShell, JSON | Main Windows config & automation; **mpv-config/** for mpv (Lua, HDR, shaders) |
| `foobar2000` | app | JS, JSON | Portable music player |
| `hedglen-profile` | docs | Markdown | GitHub profile |

## MCP Integrations

- **Gmail** - email management
- **Google Calendar** - scheduling

## Preferences & Conventions

- Commits: imperative mood, no prefix (e.g. "Add print styles", "Update contact email")
- Always review `git diff` before committing
- Push manually - do not auto-push unless asked
- Keep READMEs updated when making significant changes
- AHK lives in `dotfiles/autohotkey/main.ahk` - launched via registry Run key set by `install.ps1`

## Common Starting Points

**Workspace root:** `cd C:\Users\rjh\workstation`
**Dotfiles work:** `cd C:\Users\rjh\workstation\dotfiles`
**MPV config:** `cd C:\Users\rjh\workstation\dotfiles\mpv-config`
**Projects (junction → dotfiles):** `cd C:\Users\rjh\workstation\projects` or `cd C:\Users\rjh\workstation\dotfiles\projects`

## Canonical Path Rules

- Canonical root is always `C:\Users\rjh\workstation\`.
- New docs/scripts should prefer **relative paths**.
- `%USERPROFILE%\tools` may exist as a **compatibility junction** to `C:\Users\rjh\workstation\tools` - do not use it as the "real" path in new work.
