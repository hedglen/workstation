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
- `powershell/profile.ps1`: lightweight PowerShell 7 profile with Oh My Posh. Run `powershell/install.ps1` in preview mode first, then `-Install` to back up your existing PowerShell profile and install a loader pointing to this checkout.
- `oh-my-posh/`: prompt theme.
- `zed/`: editor settings and theme, retained for later review.
- `git/.gitconfig`: lean Git defaults, retained for later review.
- `corsair/`: preserved iCUE/Scimitar profiles and management scripts; not auto-restored.
- `scripts/rio-doctor.ps1`: optional Rio troubleshooting, modifies local Rio settings if run.
- `mpv-config/`: rebuilt minimal ModernZ + thumbfast configuration, original Scimitar bindings, preview-first staging installer. See [`mpv-config/README.md`](mpv-config/README.md).

No WSL, Scoop, AutoHotkey, Python toolchains, startup tweaks, or registry debloating.

## Website and retired projects

The website is maintained separately in [hedglen/hedglen.github.io](https://github.com/hedglen/hedglen.github.io). Its 31 tracked files matched the prior workstation copy. The custom media-organizer and yt-dlp wrapper were retired. All prior content remains accessible in Git history.

## Verification and next steps

- All 37 WinGet package IDs passed validation; actual installs were not tested as a batch.
- The simplified Windows-only WezTerm configuration launched successfully; the PowerShell profile has not been independently tested in a clean session.
- PowerShell profile activation is opt-in using a backup-first loader; other configuration restoration remains manual.
- mpv's baseline 4K HDR playback and ModernZ/thumbfast were tested independently; the full rebuilt configuration still needs a local staged integration test before installation.

## PowerShell profile setup

From PowerShell 7, while inside your checked-out workstation repository:

```powershell
.\powershell\install.ps1           # Preview; leaves current profile unchanged
.\powershell\install.ps1 -Install  # Backup existing profile and install loader
```

Open a **new** PowerShell 7 window afterward. Your existing prompt theme is preserved, but the obsolete `orgmed`, `ytdl`, transcription, Scoop, and WSL startup helpers are not included. The installer never deletes the old profile; its backup remains alongside the new loader. Avoid moving your repo after installation without rerunning the installer.
