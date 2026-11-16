# Workstation

One Windows 11 workstation. One curated WinGet manifest. One preview-first installer.

**Review branch:** `workstation-2`. `master` is intentionally unchanged until the cleanup is reviewed and tested.

## Software

`apps.json` is the source of truth for 37 WinGet applications, including Scrivener, EarTrumpet, Snipaste, Discord, and Battle.net. NVIDIA App, Revo Uninstaller Pro Portable, license activation, and ModernZ configuration are documented as manual steps in the manifest. Roon remains optional.

## Getting started

Clone this branch to `$HOME\workstation` for the configuration paths below:

```powershell
git clone --branch workstation-2 https://github.com/hedglen/workstation.git "$HOME\workstation"
cd "$HOME\workstation"
.\install.ps1                           # Preview, makes no changes
.\install.ps1 -Validate -ContinueOnError # Validate package IDs
.\install.ps1 -Install -ContinueOnError  # Install packages
.\scripts\health.ps1                     # Read-only health checks
.\maintenance\update.ps1                # Preview app upgrades
.\maintenance\update.ps1 -Upgrade       # Attempt upgrades
```

**No installer, updater, or configuration is automatically executed by cloning this repository.** Review scripts before running them.

## Configurations

- `wezterm/`: Windows-only PowerShell tabs and neon theme; no WSL or Linux shell dependency.
- `powershell/profile.ps1`: lightweight PowerShell 7 profile and Oh My Posh prompt. Copy manually after review.
- `oh-my-posh/`: prompt theme.
- `zed/`: editor settings and theme, retained for later review.
- `git/.gitconfig`: lean Git defaults, retained for later review.
- `corsair/`: preserved iCUE/Scimitar profiles and management scripts; not auto-restored.
- `scripts/rio-doctor.ps1`: optional Rio troubleshooting, modifies local Rio settings if run.
- `mpv-config/`: **preserved completely unchanged** until a separate, ground-up mpv review.

No WSL, Scoop, AutoHotkey, Python toolchains, startup tweaks, or registry debloating.

## Website and retired projects

The website is maintained separately in [hedglen/hedglen.github.io](https://github.com/hedglen/hedglen.github.io). Its 31 tracked files matched the prior workstation copy. The custom media-organizer and yt-dlp wrapper were retired. All prior content remains accessible in Git history.

## Before merging

1. Validate all 37 WinGet IDs on Windows and test installs as needed.
2. Verify WezTerm and PowerShell configs on the actual PC. No automatic config restore yet.
3. Review remaining Zed, Git, Corsair, and utility files.
4. Review the branch diff, merge into `master`, and retire `workstation-2`.
5. Rebuild mpv separately after repository cleanup.
