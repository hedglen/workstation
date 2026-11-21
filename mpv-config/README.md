# mpv for Workstation

**Windows 11 / 4K HDR OLED / NVIDIA / ModernZ**, built from the tested `gpu-next` + D3D11VA playback baseline. The repository provides the complete reproducible configuration.

## Configuration features

- `gpu-next`, `gpu-api=auto`, `hwdec=auto-safe`. Windows HDR remains enabled in Windows Settings; no HDR switching utility or forced 400-nit target.
- ModernZ: near-black chrome, vivid purple accent, Fluent icons. thumbfast: 320×180 seek previews.
- Only a requested local file is opened (`autocreate-playlist=no`). Explicit favorites playlist remains available on Scimitar button 4.
- Resume per-file viewing position, globally remember volume/mute (maximum 100%).
- English audio preferred, stereo PCM to headphones/DAC; properly flagged forced English subtitles selected automatically, full English subtitles not selected by default.
- Keyboard, mouse, and 12 Scimitar button assignments, including Num Lock on/off variants.

## Enhanced low-resolution video (optional)

For low-resolution sources around **240p–720p**, mpv includes an optional **FSRCNNX 2x** shader by igv. This is GPU neural super-resolution, not true restoration of discarded source detail. It can make some material more defined, but heavily compressed 240p clips may still have blockiness or ringing. Standard playback is **unchanged by default**, including HDR and hardware decoding.

**Toggle during playback:** **Ctrl+F8** turns FSRCNNX on/off. It does not permanently enable the shader and does not change Scimitar buttons. The shader attempts a 2x enhancement stage; normal mpv scaling handles the remaining distance to 4K. Press **i** for mpv playback statistics; compare image quality and dropped frames with the shader on and off. The lighter FSRCNNX variant is selected for a better chance at smooth 60-fps playback with the RTX 3070 Ti.

### Add this to an existing working mpv installation

The full mpv configuration installer replaces the active AppData configuration (with backup), so **do not use it just to add upscaling**. Instead, pull the latest Workstation repository and use the narrow standalone upgrade:

```powershell
git -C "$HOME\workstation" pull --ff-only origin master
& "$HOME\workstation\mpv-config\install-upscaling.ps1"          # Preview: no changes
& "$HOME\workstation\mpv-config\install-upscaling.ps1" -Install # One shader + Ctrl+F8 binding
```

This downloads the FSRCNNX shader to `%APPDATA%\mpv\shaders\FSRCNNX_x2_8-0-4-1.glsl`, verifies it resembles an mpv GLSL shader, and appends **one** keybinding only if it is missing. The existing `input.conf` is backed up before any edit. It does not replace `mpv.conf`, ModernZ, thumbnails, favorite lists, subtitle preferences, or Scimitar bindings. It refuses to edit through active AppData symlinks or portable config overrides.

Restart mpv, load a 240p/480p/720p video, and press **Ctrl+F8** to switch. Repeating the key toggles back to regular playback. If you don't like the effect on a particular clip, leave it off.

### On a fresh PC

The **normal** `mpv-config/install.ps1 -Mode Stage` and `-Mode Install` procedures include the official FSRCNNX 1.1 shader as an additional upstream asset and install the Ctrl+F8 binding from `input.conf`. You do **not** need to run `install-upscaling.ps1` after a successful fresh config installation.

Upstream shader: [igv/FSRCNN-TensorFlow release 1.1](https://github.com/igv/FSRCNN-TensorFlow/releases/tag/1.1). The source is downloaded at installation time, not stored in Git. Online access is required.

## Safe staging and installation

The main workstation WinGet installer installs `shinchiro.mpv`. This separate script stages configuration and upstream ModernZ/thumbfast/FSRCNNX assets; it does not install mpv, FFmpeg, yt-dlp, alter PATH, or modify file associations.

```powershell
cd "$HOME\workstation\mpv-config"
.\install.ps1 -Mode Diagnose   # Inspect mpv executable locations and overrides
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
Get-Item "$env:APPDATA\mpv" -Force -ErrorAction SilentlyContinue |
    Select-Object FullName, LinkType, Target
Get-ChildItem "$HOME\tools\mpv\portable_config" -Force -ErrorAction SilentlyContinue
```

**Critical: mpv portable-config precedence.** A `portable_config` directory or junction beside the mpv executable takes priority over `%APPDATA%\mpv`. If a different mpv executable or portable configuration is found, inspect it before proceeding. AppData settings are ignored when the launched executable uses its own portable configuration.

The installer now **warns in Preview and refuses Install** if an executable on PATH has a `portable_config` override. To fix a legacy junction, verify its target and back up anything important, then remove **only the junction**, not the destination directory. In PowerShell, for a *verified* junction `$HOME\tools\mpv\portable_config`, use:

```powershell
# Only after Get-Item confirms LinkType = Junction and the old target is known.
cmd /c rmdir "$HOME\tools\mpv\portable_config"
```

If it's a real directory rather than a junction, **do not** run the junction removal command. Rename/back it up after inspection. Never delete legacy configs recursively as a shortcut.

Once the portable override is resolved, choose to install:

```powershell
.\install.ps1 -Mode Install
```

This moves an existing `%APPDATA%\mpv` directory to a timestamped backup, installs the new configuration, and copies available favorites, saved volume and watch-later state from that backup. It refuses to replace an AppData junction/symlink or install while detected portable overrides exist.

**Important:** The installed WinGet build, your current PATH, and the app's active config location should be verified before switching away from your desktop test config. This repository does not automatically touch any active configuration.

## Dependencies

Downloaded on staging or installation. ModernZ/thumbfast are pinned to upstream Git commits; FSRCNNX uses its upstream 1.1 release:

- ModernZ `579897e8c974c380caa5017dc7b27a69123c1333` (`modernz.lua`, `modernz-icons.ttf`), https://github.com/Samillion/ModernZ
- thumbfast `0f711de3138c9bd6718209d819ac54022c23ded2` (`thumbfast.lua`), https://github.com/po5/thumbfast
- FSRCNNX 1.1 `FSRCNNX_x2_8-0-4-1.glsl`, https://github.com/igv/FSRCNN-TensorFlow/releases/tag/1.1

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

Buttons 9, 11, and 12 use KP3, F10, and F11 respectively.

The favorites removal menu uses mpv's native `mp.input.select`, not uosc. The A-B and boss key scripts use direct forced bindings. No automatic directory playlist is loaded. If Scimitar input differs due to iCUE, adjust the keyboard mappings in `input.conf`.

## Notes and caveats

- Some videos have no forced subtitle track or incorrectly flag it, in which case manual selection with `s` is needed. If the selected subtitle behavior varies with audio language, inspect the track flags.
- The `favorites.txt`, `volume.conf`, and `watch_later/` data files are local runtime state, not Git-tracked. The install backup can retain prior runtime state for manual migration.
- The new audio setup decodes multichannel audio to stereo PCM; it does **not** bitstream Dolby Atmos to the Element IV.
- No automatic shader activation, HDR toggling, GIF/clip export, standalone FFmpeg, SponsorBlock, or yt-dlp integration. Optional FSRCNNX is toggled manually with Ctrl+F8.
- This configuration works on the current PC. A **fresh-PC rebuild remains untested**; run `-Mode Stage` and validate controls before installing.
