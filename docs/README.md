# Documentation index

Long-form workstation guides live in **this `docs/` folder** (same repo as `install.ps1`).

## Documentation conventions

- Use **sentence case** for headings.
- Use `/` for repo-relative paths (example: `dotfiles/docs/workstation-setup.md`).
- Use `\` only in Windows absolute path or PowerShell examples.
- Prefer `$HOME`-based examples over hardcoded usernames.
- For PowerShell commands, prefer `Set-Location` over hardcoded `cd C:\...`.
- Keep markdown tables in standard delimiter style: `| --- | --- |`.

| File | Purpose |
| --- | --- |
| [**workstation-setup.md**](workstation-setup.md) | Rebuild, verify, dry-runs, health checks — the main runbook |
| [**workstation-layout.md**](workstation-layout.md) | Canonical folder layout under `%USERPROFILE%\workstation` (including junctions) |
| [**workstation-tools.md**](workstation-tools.md) | What each installed tool is for; PowerShell helpers; links to app manifests |
| [**clean-reinstall-README.md**](clean-reinstall-README.md) | Pre-wipe and post-wipe checklist for fast rebuild with `install.ps1` |
| [**directory-opus.md**](directory-opus.md) | Directory Opus layout, prefs, and shortcuts |

**Bundled Python helpers** (venvs from `install.ps1`): **`../projects/media-organizer`**, **`../projects/ytdl`**.

**Bundled mpv config** (junction from install.ps1 when applicable): **../mpv-config**.

Personal notes (markdown): **`../notes/`**.

Shorter per-package notes: **`../apps/winget-packages.md`**, **`../apps/scoop-packages.md`**.
