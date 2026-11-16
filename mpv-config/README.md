# mpv for Workstation

**Windows 11 / 4K HDR OLED / NVIDIA / ModernZ**, built from the tested `gpu-next` + D3D11VA playback baseline. This folder replaces the old ultrawide/uosc configuration; its previous files remain in Git history.

## Configuration features

- `gpu-next`, `gpu-api=auto`, `hwdec=auto-safe`. Windows HDR remains enabled in Windows Settings; no HDR switching utility or forced 400-nit target.
- ModernZ: near-black chrome, vivid purple accent, Fluent icons. thumbfast: 320×180 seek previews.
- Only a requested local file is opened (`autocreate-playlist=no`). Explicit favorites playlist remains available on Scimitar button 4.
- Resume per-file viewing position, globally remember volume/mute (maximum 100%).
- English audio preferred, stereo PCM to headphones/DAC; properly flagged forced English subtitles selected automatically, full English subtitles not selected by default.
- Keyboard, mouse, and 12 Scimitar button assignments kept from old setup, including Num Lock on/off variants.

## Safe staging and installation

The main workstation WinGet installer installs `shinchiro.mpv`. **Do not run the old mpv download installer from Git history.** This separate script stages configuration and pinned upstream ModernZ/thumbfast assets; it does not install mpv, FFmpeg, yt-dlp, alter PATH, or modify file associations.

```powershell
cd "$HOME\workstation\mpv-config"
.\install.ps1                  # Preview (no changes)
.\install.ps1 -Mode Stage      # Create independent test config on Desktop
```

The staging script prints a folder path. **Stage is not an active installation**; Preview and Stage do not update AppData or change which config normal mpv playback uses. Test it with the video of your choice:

```powershell
mpv --config-dir="C:\path\printed\by\staging" "D:\Media\video.mkv"
```

After testing **ModernZ, thumbnails, subtitles, favorites, Scimitar and resume**, confirm the active executable and its configuration location:

```powershell
Get-Command mpv -All | Select-Object Name, Source
Get-Item "$env:APPDATA\\mpv" -Force -ErrorAction SilentlyContinue |
    Select-Object FullName, LinkType, Target
Get-ChildItem "$HOME\\tools\\mpv\\portable_config" -Force -ErrorAction SilentlyContinue
```

**Critical: mpv portable-config precedence.** A `portable_config` directory or junction beside the mpv executable takes priority over `%APPDATA%\\mpv`. This caused the November 2026 regression: the first `mpv.exe` on PATH was in `%USERPROFILE%\\tools\\mpv`, and its `portable_config` junction pointed at an old workstation config. The correct ModernZ config was already present under AppData but never loaded.

The installer now **warns in Preview and refuses Install** if an executable on PATH has a `portable_config` override. To fix a legacy junction, verify its target and back up anything important, then remove **only the junction**, not the destination directory. In PowerShell, for the *verified* old junction `$HOME\\tools\\mpv\\portable_config`, use:

```powershell
# Only after Get-Item confirms LinkType = Junction and the old target is known.
cmd /c rmdir "$HOME\\tools\\mpv\\portable_config"
```

If it's a real directory rather than a junction, **do not** run the junction removal command. Rename/back it up after inspection. Never delete legacy configs recursively as a shortcut.

Once the portable override is resolved, choose to install:

```powershell
.\install.ps1 -Mode Install
```

This moves existing `%APPDATA%\mpv` to a timestamped backup and puts the new config there. It refuses to replace a junction/symlink. If you previously used `portable_config` next to `mpv.exe`, that may take precedence over `%APPDATA%\mpv`: remove/rename the legacy portable config manually *after backing it up* or keep launching with `--config-dir` during testing.

**Important:** The installed WinGet build, your current PATH, and the app's active config location should be verified before switching away from your desktop test config. This repository does not automatically touch any active configuration.

## Dependencies

Downloaded on staging or installation, pinned to upstream Git commits:

- ModernZ `579897e8c974c380caa5017dc7b27a69123c1333` (`modernz.lua`, `modernz-icons.ttf`), https://github.com/Samillion/ModernZ
- thumbfast `0f711de3138c9bd6718209d819ac54022c23ded2` (`thumbfast.lua`), https://github.com/po5/thumbfast

They are not copied into Git because the installer obtains them from the maintainers. Internet access is required while staging. The original projects retain their own licenses.

## Mouse and Scimitar controls

| Button | Action | iCUE assignment |
|---|---|---|
| Left-click | Play/pause | Mouse left |
| Right-click | Player menu | Mouse right |
| Middle-click | Quit | Mouse middle |
| Wheel up/down | Volume ±2 | Wheel |
| 1 | Fullscreen | KP7 |
| 2 | Previous video | KP8 |
| 3 | Next video | KP9 |
| 4 | Open favorites | KP4 |
| 5 | Previous frame | KP5 |
| 6 | Next frame | KP6 |
| 7 | Mute | KP1 |
| 8 | Reset A-B loop | KP2 |
| 9 | Set A point | KP3 |
| 10 | Pause and minimize | KP0 |
| 11 | Toggle file loop | F10 |
| 12 | Set B point | F11 |

Additional mappings: Ctrl+2/3 (previous/next chapter), Ctrl+4 (add favorite), Alt+4 (remove favorite). Those modifiers mean Ctrl/Alt held while using the actual side button, not keyboard number keys.

Buttons 9, 11, and 12 were verified against iCUE screenshots: KP3, F10, and F11 respectively.\n\nThe favorites removal menu uses mpv's native `mp.input.select`, not uosc. The A-B and boss key scripts use direct forced bindings. No automatic directory playlist is loaded. If Scimitar input differs due to iCUE, adjust the keyboard mappings in `input.conf`.

## Notes and caveats

- Some videos have no forced subtitle track or incorrectly flag it, in which case manual selection with `s` is needed. If the selected subtitle behavior varies with audio language, inspect the track flags.
- The `favorites.txt`, `volume.conf`, and `watch_later/` data files are local runtime state, not Git-tracked. The install backup can retain prior runtime state for manual migration.
- The new audio setup decodes multichannel audio to stereo PCM; it does **not** bitstream Dolby Atmos to the Element IV.
- No historical shader stacks, automatic HDR toggling, GIF/clip export, standalone FFmpeg, SponsorBlock, or yt-dlp integration.
- This configuration was confirmed working on the existing PC in November 2026 after removing an obsolete `portable_config` junction. A **fresh PC rebuild remains untested**; run `-Mode Stage` and validate controls before installing.
