# Workstation

A lean, repeatable Windows 11 setup. **One repository, one canonical branch (`master`), one curated 37-app WinGet manifest.** No WSL, no mandatory Scoop, no automatic system debloating.

## Fresh Windows installation: do this in order

Use **PowerShell 7** once WinGet and Git are available. Windows PowerShell 5.1 can bootstrap Git, but the configuration scripts target PowerShell 7.

1. Install and update Windows 11, NVIDIA GPU driver and essential hardware drivers. Ensure Microsoft App Installer / WinGet is present.
2. Install **Git for Windows** and **PowerShell 7** if necessary, then clone **to a single canonical path**:

   ```powershell
   git clone --branch master https://github.com/hedglen/workstation.git "$HOME\workstation"
   Set-Location "$HOME\workstation"
   ```

   If that directory already exists, use `git -C "$HOME\workstation" pull --ff-only origin master` instead. Use one working checkout; do not create configuration junctions or symlinks pointing into it.

3. Check the software manifest, then install only the 37 curated entries:

   ```powershell
   .\install.ps1                            # Preview, read-only
   .\install.ps1 -Validate -ContinueOnError # Check WinGet IDs
   .\install.ps1 -Install -ContinueOnError  # Perform installs
   ```

   App installs are opt-in; the repository does not install anything when cloned. WinGet matching may vary with installer type, Store registration or preexisting installs. Inspect results before rerunning.

4. Install the **standalone PowerShell 7 profile and Oh My Posh theme**. These are copied into your user PowerShell folder, not linked to the repository:

   ```powershell
   .\powershell\install.ps1           # Preview
   .\powershell\install.ps1 -Install  # Back up old files; copy profile and theme
   ```

   Start a **new PowerShell 7** window afterward. The installed profile and theme work even when GitHub is unavailable or the repository moves. Optional `dots` / `apps-*` commands expect the canonical `$HOME\workstation` checkout; the prompt itself does not. To apply later profile/theme changes from GitHub, rerun `powershell/install.ps1 -Install` after pulling.

5. **Install independent WezTerm and Zed configurations.** These commands copy files into the application-owned configuration directories. They do not create symlinks or junctions.

   **WezTerm**: from PowerShell 7, after WinGet has installed WezTerm:

   ```powershell
   $source = "$HOME\workstation\wezterm"
   $dest = "$HOME\.config\wezterm"
   if (Test-Path -LiteralPath $dest) {
       throw "WezTerm config already exists at $dest. Back it up and inspect any junction before replacing it."
   }
   New-Item -ItemType Directory -Path "$HOME\.config" -Force | Out-Null
   Copy-Item -LiteralPath $source -Destination $dest -Recurse -ErrorAction Stop
   Test-Path "$dest\wezterm.lua"
   Test-Path "$dest\modules\theme.lua"
   ```

   A fresh install should show `True` twice. Restart WezTerm; its configuration will work independently of Git. If an existing `$HOME\.config\wezterm` is a **junction**, do not copy over it. Stage the files under a temporary new name, verify them, then remove **only the verified junction** using `cmd /c rmdir` and rename the staged folder, as described below.

   **Zed**: after installing Zed, close the editor before copying. For a fresh PC with no personal Zed settings:

   ```powershell
   $source = "$HOME\workstation\zed"
   $dest = "$env:APPDATA\Zed"
   New-Item -ItemType Directory -Path "$dest\themes" -Force | Out-Null
   foreach ($name in @('AGENTS.md','keymap.json','settings.json','themes\rio-neon-city.json')) {
       $target = Join-Path $dest $name
       if (Test-Path -LiteralPath $target) { throw "Already exists: $target. Back it up before restoring." }
       Copy-Item -LiteralPath (Join-Path $source $name) -Destination $target -ErrorAction Stop
   }
   ```

   These commands refuse to replace existing settings. If a prior install used symbolic links, inspect each with `Get-Item -Force | Select-Object FullName,LinkType,Target`, stage copies from Git separately, and replace **only confirmed symbolic links** while preserving originals and backups. Keep all four installed settings files as normal files.

   **Windows Terminal (optional)**: Windows Terminal is not required when using WezTerm. On a fresh Windows installation, use its built-in settings; no repository link is installed. If recovering settings from an existing workstation, copy a verified `settings.json` into its user `LocalState` folder, never symlink it.

   **Git, Rio, and Corsair iCUE**: Review their individual configuration folders and restore only what you need. Rio is optional as a second terminal; `scripts/rio-doctor.ps1` is read-only unless invoked with `-Apply`. iCUE backups are preserved but are not auto-restored.

6. **Set up mpv as a separate, required configuration step.** WinGet installs the player binary, **not ModernZ or the optional FSRCNNX upscale shader**. For an independent configuration that does not depend on the Git repository:

   ```powershell
   Set-Location "$HOME\workstation\mpv-config"
   .\install.ps1 -Mode Diagnose  # Read-only. Checks mpv locations and portable overrides
   .\install.ps1                 # Preview, no changes
   .\install.ps1 -Mode Stage     # Downloads an independent Desktop test config
   ```

   Test with a local video using the path printed by Stage:

   ```powershell
   mpv --config-dir="C:\path\to\mpv-modernz-test-folder" "D:\path\to\video.mkv"
   ```

   When ModernZ, thumbnails, subtitles and Scimitar buttons work, and Diagnose finds no legacy `portable_config` beside the mpv executable:

   ```powershell
   .\install.ps1 -Mode Install   # Backs up old AppData config and activates ModernZ
   .\install.ps1 -Mode Diagnose  # Confirm executable and configuration paths
   ```

   **Do not stop after Preview or Stage**: neither makes the normal mpv launch use ModernZ or the optional FSRCNNX shader. The installer refuses to overwrite AppData if a portable override is detected. It preserves local favorites, saved volume, and watch-later state on upgrades. Read [mpv's full troubleshooting guide](mpv-config/README.md) before removing any legacy junction; never delete linked target directories as a shortcut. After installation, **Ctrl+F8** toggles FSRCNNX 2x super-resolution for low-res videos; normal HDR playback remains the default.

7. Check repository integrity and preview application maintenance:

   ```powershell
   Set-Location "$HOME\workstation"
   .\scripts\health.ps1
   .\maintenance\update.ps1           # Preview only
   # .\maintenance\update.ps1 -Upgrade # Opt-in upgrades
   ```

## Optional upgrade: enhanced 240p–720p mpv playback

If this PC already has a working ModernZ installation and you want to add the **Ctrl+F8** FSRCNNX upscale toggle without reinstalling its other settings, run:

```powershell
git -C "$HOME\workstation" pull --ff-only origin master
& "$HOME\workstation\mpv-config\install-upscaling.ps1"          # Preview only
& "$HOME\workstation\mpv-config\install-upscaling.ps1" -Install # Shader and keybinding only
```

Restart mpv and press **Ctrl+F8** during playback to enable/disable enhanced upscaling. The shader is **off by default**. This is independent from the main app installer and preserves your existing mpv configuration. See [mpv enhancement details](mpv-config/README.md#enhanced-low-resolution-video-optional).

## Software policy

- **Curated WinGet applications:** The 37 exact IDs in [apps.json](apps.json) are the rebuild baseline.
- **Keep as manual/Steam-managed exceptions:** Adobe Creative Cloud and existing Adobe applications, Lossless Scaling, YoloMouse, NVIDIA App, and Revo Uninstaller Pro Portable.
- **Optional, not automatically installed:** Roon. Existing Scoop command-line tools are under review, not a fresh-PC requirement.
- **Not in the rebuild:** WSL, Ubuntu, Visual Studio/Cursor/Windsurf toolchains, standalone Python/Node/.NET SDKs, PowerToys, additional media players, and portable mpv overrides.
- **Do not blindly uninstall:** NVIDIA/Corsair/JDS drivers, Microsoft VC++ and .NET runtimes, Microsoft Store frameworks, Steam games and anti-cheat components.

## Configurations

| Folder | Purpose |
| --- | --- |
| `wezterm/` | Windows-only WezTerm appearance and tabs |
| `powershell/` and `oh-my-posh/` | Colorful PowerShell 7 prompt and theme; backup-first **independent file copies**, no loader/link |
| `mpv-config/` | ModernZ, thumbfast, HDR/GPU playback, Scimitar controls and playback scripts |
| `corsair/` | iCUE/Scimitar profile backups, reviewed/restored manually |
| `zed/` | Editor preferences |
| `git/` | Git defaults |
| `maintenance/` | Preview-first app upgrades |
| `scripts/` | Health checks and optional diagnostics |

## Verification and limitations

- All 37 manifest IDs previously passed WinGet validation, but a fresh-PC end-to-end install has **not** been tested.
- mpv ModernZ/thumbfast is working on the current Windows PC. A **fresh-PC build remains untested**.
- The mpv installer downloads pinned ModernZ/thumbfast assets from their upstream repositories, so network access is required for Stage/Install.
- Existing local mpv favorites and watch-later state are runtime data, not tracked in Git. Fresh PCs do not inherit them without a separate personal backup.
- A successful WinGet binary install does not mean app configuration was restored. Check each application individually.
- The root `install.ps1` only previews, validates, or installs manifest WinGet applications. It does **not** create symlinks/junctions, change PATH, configure PowerShell or mpv, restore Corsair profiles, modify the registry, or run troubleshooting scripts.
- `powershell/install.ps1 -Install` only copies two files with backups to the current user's PowerShell profile directory. `mpv-config/install.ps1 -Mode Install` independently updates AppData with backup/override checks. Corsair restore and Rio troubleshooting are separate opt-in actions; `scripts/rio-doctor.ps1` is preview-only unless `-Apply` is specified.
- The personal website lives separately at [hedglen/hedglen.github.io](https://github.com/hedglen/hedglen.github.io). This repository contains only active workstation files and opt-in backups/templates; Git history remains unchanged.

## Maintenance

Update your canonical local checkout with:

```powershell
git -C "$HOME\workstation" pull --ff-only origin master
```

All setup scripts are designed to be **preview-first**. No registry debloating, forced file associations, automatic driver deletion, or destructive app cleanup.
