# mpv-config

> Personal mpv configuration for Windows — tuned for an **LG UltraGear 34GP83A-B** (3440×1440 @ 160Hz, DisplayHDR 400) with an **NVIDIA RTX 3070 Ti**. Built for quality, control, and daily use. **[Controls cheat sheet](#controls-cheat-sheet)** (mouse + every key).

---

## Quick Install

Primary source: **[hedglen/workstation](https://github.com/hedglen/workstation)** (this folder is **`mpv-config/`** inside that repo).

Open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/hedglen/workstation/master/mpv-config/install.ps1 | iex
```

**Requires:** [7-Zip](https://7-zip.org) (or another archiver the script accepts). **Git is not required** for the config itself: the installer can junction **`tools\mpv\portable_config`** to your **`workstation\mpv-config`** checkout (bundled with the workstation repo).

On a machine bootstrapped with [hedglen/workstation](https://github.com/hedglen/workstation), **Git**, **`shinchiro.mpv`**, and yt-dlp are often already present via winget.

The installer will:
- Download the latest mpv build (shinchiro x86_64)
- Download yt-dlp (stream YouTube, Twitch, etc.)
- Download HdrSwitcher (Windows HDR toggling)
- Point **`portable_config`** at this folder (junction or symlink under **`tools\mpv`** when applicable)
- Create a desktop shortcut and add mpv to your PATH


---

## 🔧 Manual Install

1. Download mpv from [shinchiro's builds](https://github.com/shinchiro/mpv-winbuild-cmake/releases) and extract to `$HOME\workstation\tools\mpv`
2. Junction or symlink **`portable_config`** to your **`workstation\mpv-config`** checkout (same repo when you use [hedglen/workstation](https://github.com/hedglen/workstation)), e.g. target `$HOME\workstation\mpv-config` for `$HOME\workstation\tools\mpv\portable_config`
3. Download [yt-dlp.exe](https://github.com/yt-dlp/yt-dlp/releases/latest) into `$HOME\workstation\tools\mpv`
4. Download [HdrSwitcher.zip](https://github.com/Vaiz/HdrSwitcher/releases/latest), extract, and copy `HdrSwitcher.exe` into `$HOME\workstation\tools\mpv\portable_config` as `hdrswitch.exe`
5. The single-instance launchers (`mpv-single.bat`, `mpv-single.ps1`) live alongside `mpv.exe` in `tools\mpv\` — use `mpv-single.bat` for file associations

---

## ✨ Features

### Picture Quality
- **gpu-next** video output (libplacebo) with **Vulkan** and nvdec hardware decoding
- **Auto upscaling** by source resolution:
  - **≤480p** → fast bilateral denoise → **FSRCNNX x2** (56-16-4-1) → **FSRCNNX x2** (16-0-4-1) → adaptive sharpen *(heavy clean-up from SD / 480p)*
  - **481p–720p** → FSRCNNX x2 56-16-4-1 + adaptive sharpen
  - **721p–1080p** → SSimDownscaler + FSRCNNX x2 56 *(upscale then high-quality downscale to your panel)*
  - **1081p+** → no extra user shaders *(native or above your target resolution)*
- **Anime4K** shaders for animated content
- **Ctrl+0–4** manual shader overrides; **`mpv.conf`** still auto-picks shaders by resolution until you change them
- Vivid, punchy SDR picture (tuned brightness, contrast, saturation)
- **Deband filter** off by default; press **`d`** to toggle when you see banding (8-bit gradients, etc.)
- **Gamut mapping** set to `auto` for accurate wide-color content

### HDR
- **Auto HDR switching** — detects PQ/HLG/BT.2020 content and toggles Windows HDR on/off automatically
- Equalizer resets when HDR is active (prevents color mangling)
- Restores SDR picture settings when HDR content ends
- Works seamlessly with single-instance file switching
- Manual override and status display

### Workflow
- **Single-instance mode** — opening a new file loads it into the existing window
- **Window memory** — remembers size and position between every session
- **Volume memory** — volume and mute state persist between sessions
- **Auto-load folder** — opening any video queues up the entire folder as a playlist
- **Favorites** — save, load, and manage a personal playlist
- **Chapter editor** — add chapter markers while playing and save them into the file
- **Clip export** — mark in/out points and export clips with ffmpeg (no re-encode)
- **Boss key** — instantly pause and minimize
- **A/B loop** — independently mark A, B, and reset points
- **SponsorBlock** — skip sponsor segments automatically
- **GIF creation** — mark start/end and export animated GIFs
- **yt-dlp** — stream from YouTube, Twitch, and hundreds of other sites
- **Audio normalization** — dynamic volume leveling for inconsistent content

### UI
- **uosc** — modern interface with timeline, controls, and right-click context menu
- **Neon purple** theme
- **Seek bar thumbnails** — hover to preview any frame
- **Playlist manager** — visual playlist browser

---

## Controls cheat sheet

Single-page reference for [`input.conf`](input.conf). The lowercase **`h`** binding comes from [`hdr-auto.lua`](scripts/hdr-auto.lua) (HDR status OSD), not `input.conf`.

**Corsair Scimitar:** side buttons are mapped to numpad keys — see the [dedicated section](#-corsair-scimitar-side-buttons) (same actions, Num Lock on or off).

### Mouse

| Input | Action |
|-------|--------|
| Left click | Play / pause |
| Middle click | Quit |
| Right click | uosc context menu |
| Wheel up / down | Volume ±2 |

### Quit, fullscreen, UI chrome

| Input | Action |
|-------|--------|
| `Space`, `Q` | Quit (no watch-later) |
| `q` | Quit and save position |
| `Esc` | Exit fullscreen |
| `f`, `Alt+Enter` | Toggle fullscreen |
| `Tab` | Toggle built-in OSC |
| `k`, `Ctrl+T` | Toggle always on top |
| `Ctrl+D` | Toggle window dragging |
| `Ctrl+M` | Toggle window border |
| `Alt+1` … `Alt+4` | Window scale 50% / 100% / 150% / 200% |
| `Alt+R` | Toggle 21:9 aspect override vs default |

### Playback, seek, speed

| Input | Action |
|-------|--------|
| `←` / `→` | Seek ±5s |
| `Shift+←` / `Shift+→` | Seek ±60s |
| `Ctrl+←` / `Ctrl+→` | Seek ±5min |
| `,` / `.` | Frame back / forward |
| `[` / `]` | Speed ×0.9 / ×1.1 |
| `<` / `>` | Half / double speed |
| `Backspace` | Reset speed |

### Playlist

| Input | Action |
|-------|--------|
| `PgUp` / `PgDn` | Previous / next file |
| `Home` | First file in playlist |
| `End` | Next playlist |
| `Ctrl+L` | Playlist manager |

### Picture (EQ) & video

| Input | Action |
|-------|--------|
| `1` / `2` | Brightness ± |
| `3` / `4` | Contrast ± |
| `5` / `6` | Saturation ± |
| `7` / `8` | Gamma ± |
| `9` | Vivid baseline (matches `mpv.conf`) |
| `0` | Neutral EQ |
| `d` | Toggle deband |
| `D` | Toggle deinterlace |
| `n` | Toggle unscaled video |
| `C` | Cycle aspect (16:9 → 21:9 → 4:3 → 2.35:1 → default) |
| `Ctrl+R` | Rotate 90° / 180° / 270° / 0 |
| `Ctrl+H` | Cycle hwdec: auto-safe → no → auto |

### Shaders

| Input | Action |
|-------|--------|
| `Ctrl+1` | FSRCNNX x2 56 (live-action) |
| `Ctrl+2` | Anime4K stack |
| `Ctrl+3` | SSim + FSRCNNX |
| `Ctrl+4` | Built-in sharp scaling, clear user shaders |
| `Ctrl+0` | Bilinear scaling, clear user shaders |

### Audio

| Input | Action |
|-------|--------|
| `↑` / `↓` | Volume ±2 |
| `Ctrl+↑` / `Ctrl+↓` | Volume ±10 |
| `m` | Mute |
| `a` / `A` | Cycle audio track (forward / back) |
| `x` / `X` | Audio delay ±50ms |
| `Ctrl+X` | Reset audio delay |
| `Alt+N` | Toggle audio normalization |
| `c` | Cycle audio visualizer |

### Subtitles

| Input | Action |
|-------|--------|
| `s` / `S` | Cycle sub track (forward / back) |
| `v` | Toggle subtitle visibility |
| `Shift+G` / `Shift+F` | Subtitle scale ± |
| `E` / `R` | Subtitle blur ± |
| `z` / `Z` | Sub delay ±50ms |
| `Ctrl+Z` | Reset sub delay |
| `u` | Toggle grayscale subs |
| `U` | Toggle blend-subtitles |
| `p` | Toggle sub fix timing |
| `g` | Reload subtitles |
| `l` | Cycle ASS override |
| `Ctrl+S` | Cycle secondary subtitle |

### Stats & lists

| Input | Action |
|-------|--------|
| `i` | Toggle stats overlay |
| `I` | Stats detailed page |
| `F1` / `F2` / `F3` | OSD: playlist / track list / chapter list |

### Timestamps, GIF, clips, shots

Screenshots: `P:\Media\Photos\Screenshots`.

| Input | Action |
|-------|--------|
| `Ctrl+C` | Copy timestamp to clipboard |
| `Ctrl+T` | Toggle timestamp seeker input |
| `Ctrl+V` | Seek to timestamp from clipboard |
| `b` / `B` | GIF start / end mark |
| `Ctrl+B` / `Ctrl+Shift+B` | Export GIF / GIF with subs |
| `Ctrl+I` / `Ctrl+O` | Clip IN / OUT |
| `Ctrl+E` | Export clip (stream copy) |
| `Ctrl+P` | Clip IN/OUT status |
| `F12` | Screenshot (`mpv.conf` path & format) |
| `Ctrl+S` | Screenshot video only |
| `Ctrl+Alt+S` | Screenshot window |

### Chapters, HDR, SponsorBlock

| Input | Action |
|-------|--------|
| `t` / `T` | Add chapter / save chapters |
| `Ctrl+F14` / `Ctrl+F15` | Previous / next chapter |
| `H` | Manual HDR toggle |
| `h` | HDR status (gamma, primaries, on/off) |
| `Alt+B` | Toggle SponsorBlock |

---

## 🎮 Corsair Scimitar Side Buttons

Map buttons 1–12 to **Numpad keys** in iCUE (Keyboard action, no modifier). **Num Lock on or off:** `input.conf` binds both the digit/dot/minus keys (lock on) and the navigation aliases (lock off), including **numpad −** (`KP_SUBTRACT`) for button 12 in both sections so mark B always works.

**Buttons 8–10 and 12 (A-B + boss)** are **not** in `input.conf`. **`boss-key.lua`** and **`ab-loop-manager.lua`** register them with **`mp.add_forced_key_binding`** for **`KP0`**, **`KP_INS`**, **`INS`** (boss) and **`KP2`**, **`KP3`**, **`KP_SUBTRACT`**, **`KP_DOWN`**, **`KP_PGDWN`** (A-B). That avoids `script-binding` / `script-message-to`, which can fail on some Windows mpv builds. **F20 / F21 / F22 / F24** still work as before.

```
┌─────────────┬──────────────┬──────────────┐
│ 1: Fullscr  │  2: Prev File│  3: Next File│
│   (KP 7)   │    (KP 8)   │    (KP 9)   │
├─────────────┼──────────────┼──────────────┤
│ 4: Favs     │  5: Frame ◀  │  6: Frame ▶  │
│   (KP 4)   │    (KP 5)   │    (KP 6)   │
├─────────────┼──────────────┼──────────────┤
│ 7: Mute     │  8: A-B Reset│ 9: A-B Mark A│
│   (KP 1)   │    (KP 2)   │    (KP 3)   │
├─────────────┼──────────────┼──────────────┤
│ 10: Boss Key│ 11: Loop     │ 12: A-B Mark B│
│   (KP 0)   │    (KP .)   │    (KP -)   │
└─────────────┴──────────────┴──────────────┘
```

| Button | Key | Action |
|--------|-----|--------|
| 1 | KP 7 | Toggle fullscreen |
| 2 | KP 8 | Previous file |
| 2 + Ctrl | Ctrl+KP 8 | Previous chapter |
| 3 | KP 9 | Next file |
| 3 + Ctrl | Ctrl+KP 9 | Next chapter |
| 4 | KP 4 | Open favorites playlist |
| 4 + Ctrl | Ctrl+KP 4 | Add current file to favorites |
| 4 + Alt | Alt+KP 4 | Remove from favorites |
| 5 | KP 5 | Frame step back |
| 6 | KP 6 | Frame step forward |
| 7 | KP 1 | Mute |
| 8 | KP 2 | A-B loop reset |
| 9 | KP 3 | A-B mark A |
| 10 | KP 0 | Boss key (pause + minimize) |
| 11 | KP . | Loop file toggle |
| 12 | KP - | A-B mark B |

---

## 📜 Scripts

| Script | Description |
|--------|-------------|
| `hdr-auto.lua` | Auto-detects HDR content, toggles Windows HDR, resets equalizer |
| `chapter-editor.lua` | Add chapter markers while playing and save them to the file via ffmpeg |
| `clip-export.lua` | Mark in/out points and export clips without re-encoding |
| `autoload.lua` | Automatically queues all videos in the same folder as a playlist |
| `favorites.lua` | Save, load, and manage a personal favorites playlist |
| `ab-loop-manager.lua` | Independent A, B, and reset bindings for A-B loop |
| `boss-key.lua` | Pause and minimize instantly |
| `audio-normalize.lua` | Toggle dynamic audio normalization (dynaudnorm) |
| `remember-volume.lua` | Persists volume and mute state between sessions |
| `save-geometry.lua` | Remembers window size and position between sessions |
| `sponsorblock-minimal.lua` | Skips sponsor segments via SponsorBlock API |
| `playlistmanager.lua` | Visual playlist browser |
| `thumbfast.lua` | Seek bar thumbnail preview |
| `copy-time.lua` | Copy current timestamp to clipboard |
| `mpv-gif.lua` | Export animated GIFs from video clips |
| `audio_visualizer.lua` | Audio spectrum visualizer |
| `seek-to.lua` | Seek to a typed timestamp |

---

## 🖥️ Hardware

| Component | Spec |
|-----------|------|
| Monitor | LG UltraGear 34GP83A-B — 3440×1440 @ 160Hz, DisplayHDR 400, G-SYNC |
| GPU | NVIDIA RTX 3070 Ti — 8GB VRAM, Ampere |
| RAM | 32GB |
| OS | Windows 11 |

---

## 🔁 Single-Instance Setup

To make clicking a video file always open in the existing mpv window:

1. Set **`$HOME\workstation\tools\mpv\mpv-single.bat`** as the default program for your video file types
2. It connects to mpv's named pipe (`\\.\pipe\mpvsocket`) and sends a `loadfile` command
3. Falls back to launching a new mpv instance if none is running

> The launcher scripts (`mpv-single.bat` / `mpv-single.ps1`) live in `tools\mpv\` alongside `mpv.exe` — not in this config repo.

## Compatibility

If you still have older references to `%USERPROFILE%\tools`, keep a **junction**
at `%USERPROFILE%\tools` pointing to `C:\Users\rjh\workstation\tools` so legacy
paths resolve, but treat `workstation\tools` as canonical.

## Repository hygiene

Root-level `cache/` (if mpv or scripts create it) is listed in `.gitignore` so it is not committed. Other auto-generated paths should be ignored the same way.

# maintained by hedglen
