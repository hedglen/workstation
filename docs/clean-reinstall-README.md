# Clean reinstall runbook

Practical checklist for wiping Windows, reinstalling cleanly, and getting back to a working setup with `dotfiles/install.ps1`.

## Goal

Rebuild the workstation to a reliable baseline quickly, while avoiding data loss from things that are not fully automated.

## Pre-wipe checklist

Do this before you erase the machine.

- Verify latest dotfiles are pushed:
  - `Set-Location "$HOME\workstation\dotfiles"`
  - `git status --short --branch`
  - `git push`
- Confirm critical cloud/account access works:
  - GitHub account + 2FA
  - Proton Pass (or your password manager) vault access
  - Recovery email access
- Back up non-git local data you care about:
  - media libraries, downloads, exports
  - app profiles not in this repo
  - license files/keys not stored in vault
- Save optional hardware/device exports (if needed):
  - mouse/keyboard profiles
  - fan/RGB profiles
  - audio presets

## Fresh Windows bootstrap

After a clean Windows install:

1. Install all Windows updates first.
1. Open PowerShell.
1. Confirm `winget`:

```powershell
winget --version
```

1. Install Git:

```powershell
winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
```

1. Open a new PowerShell window and run bootstrap:

```powershell
irm https://raw.githubusercontent.com/hedglen/dotfiles/master/install.ps1 | iex
```

## First-pass verification

After installer completes:

- Reload terminal and run:
  - `dots-health`
  - `dots-update -DryRun`
- Confirm workspace and key paths:
  - `$HOME\workstation\dotfiles`
  - `$HOME\workstation\tools`
  - `$HOME\workstation\rjh-workspace.code-workspace`
- Confirm WSL is usable:
  - `wsl -l -v`
  - `wsl`
- Confirm core terminal/editor setup:
  - WezTerm launches with expected tabs
  - PowerShell profile helpers exist (`dots-update`, `dots-health`, etc.)
  - VS Code / Cursor settings and extensions applied

## Manual follow-up items

These are expected post-wipe tasks.

- Sign into apps and services (GitHub CLI, Steam, Adobe, Proton, etc.).
- Handle manual-only installs (for current setup, Battle.net).
- Re-apply optional app-specific tuning that is intentionally personal.
- Validate apps that may occasionally fail in winget and retry manually if needed:
  - `winget upgrade --id Corsair.iCUE.5 --accept-package-agreements --accept-source-agreements`
  - `winget upgrade --id Adobe.CreativeCloud --accept-package-agreements --accept-source-agreements`

## Recovery order (fast path)

If you want the shortest path to productive:

1. Windows update
2. Bootstrap (`install.ps1`)
3. `dots-health`
4. `dots-update`
5. Sign-ins and license/account restores

## Notes

- `install.ps1` covers most of the machine bootstrap, but no script can restore private account sessions or data that was never backed up.
- Keep this runbook aligned with `README.md`, `docs/workstation-setup.md`, and `docs/workstation-tools.md`.
