# Workstation

One Windows 11 workstation. One curated WinGet manifest. One preview-first installer.

**Primary branch:** `master`. The cleaned workstation configuration and 37-package manifest are maintained here.

## Software

`apps.json` is the source of truth for 37 WinGet applications, including Scrivener, EarTrumpet, Snipaste, Discord, and Battle.net. NVIDIA App, Revo Uninstaller Pro Portable, license activation, and ModernZ configuration are documented as manual steps in the manifest. Roon remains optional.

## Getting started

Clone `master` to `$HOME\workstation` for the configuration paths below:

```powershell
git clone --branch master https://github.com/hedglen/workstation.git "$HOME\workstation"
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

## Verification and next steps

- All 37 WinGet package IDs passed validation; actual installs were not tested as a batch.
- The simplified Windows-only WezTerm configuration launched successfully; the PowerShell profile has not been independently tested in a clean session.
- Configuration restoration is still manual. Review local settings before replacing them.
- `mpv-config/` has deliberately been preserved unchanged and is next for a ground-up review.
