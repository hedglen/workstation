# Workstation tools — quick guide

Practical map of software on this machine: what it is for, how you invoke it, and where to read more. Complements the repo [README](https://github.com/hedglen/workstation/blob/master/README.md) (bootstrap, shell, hotkeys).

**Source of truth for installers**

- Winget: `apps/winget-packages.json` (imported by `install.ps1`; **only** copy — do not keep a duplicate under Documents) — blurbs: `apps/winget-packages.md`
- Scoop: `apps/scoop-packages.json` (`install.ps1` runs [get.scoop.sh](https://github.com/ScoopInstaller/Install) if Scoop is missing, then installs the list; **`install.ps1 -NoScoop`** skips Scoop) — blurbs: `apps/scoop-packages.md`

---

## PowerShell helpers (profile)

Defined in `powershell/profile.ps1`. Some depend on **`projects/`** (or **`workstation\projects`** when it is a junction) and **`scripts/`**.


| Command                               | Purpose                                                                                                                                              |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `drives`                              | Table of volumes, sizes, free space                                                                                                                  |
| `uptime`                              | Time since last boot                                                                                                                                 |
| `sysinfo`                             | OS, RAM, CPU, user, hostname                                                                                                                         |
| `users` / `admins`                    | Local accounts / Administrators members                                                                                                              |
| `startup-list` / `startup-find 'pat'` | Inspect Run keys                                                                                                                                     |
| `tasks-user`                          | Non-Microsoft scheduled tasks                                                                                                                        |
| `pkillf name`                         | Kill processes matching name (`-WhatIf` to preview)                                                                                                  |
| `which name`                          | Resolve a command to its path                                                                                                                        |
| `touch path`                          | Create empty file                                                                                                                                    |
| `grep pattern`                        | Pipeline `Select-String` wrapper                                                                                                                     |
| `reload`                              | Re-source `$PROFILE`                                                                                                                                 |
| `save-dots [msg]`                     | Commit and push the workstation repo                                                                                                                           |
| `sync-dots`                           | Pull the repo and relink (`update.ps1 -SkipApps`)                                                                                                    |
| `ask "…"`                             | Plain-English helper (`powershell/ask.py`, needs `python`)                                                                                  |
| `orgmed` / `orgmedx`                  | Media organizer (`projects/media-organizer`; venv from `install.ps1`) — inbox `R:\Media\x\dl`; library roots `R:\Media\Movies`, `TV Shows`, `Music Videos`, `x` (`config.toml`); `orgmedx` is `--dest x --apply`. See `organize.py --help` |
| `ytdl` / `dl`                         | yt-dlp wrapper (`projects/ytdl/ytdl.py`); `dl` is an alias; downloads to the current user's `Videos` folder by default. `--audio`, `--quality 1080|720|480|best`, `--playlist` (`workstation\projects\ytdl` works if junction exists)                                   |
| `dll`                                 | `yt-dlp --list-extractors`                                                                                                                           |
| `trans`                               | Transcribe video → `.srt` + `.md` (`scripts/transcribe.py`, venv in `tools/transcribe-env`; created by `install.ps1` — Whisper deps are a large download)                                         |
| `vtrans` / `fixsub`                   | Video OCR / translate path (`scripts/video-ocr-translate.py`)                                                                                        |
| `scimitar`                            | Corsair Scimitar helper (`corsair/scimitar.ps1`)                                                                                            |


Navigation shortcuts: `c`, `d`, `home`, `dots`, `tools`, `psh` (see README).

Startup hygiene policy: `install.ps1` and `maintenance/update.ps1` automatically remove known unwanted startup entries (`AdobeBridge`, `Adobe Acrobat Synchronizer`, `GoogleChromeAutoLaunch_2B79721E5FCF3159A6E77C5981E57BF6`, `Discord`, `org.whispersystems.signal-desktop`, `WingetUI`, `IDMan`, `LGHUB`) plus `Send to OneNote.lnk` from the user Startup folder when present.

---

## Git Bash (optional)

**Git for Windows** includes Git Bash. Its default `ll` is not the same as pwsh’s `ll` (which is `Get-ChildItem`).

Optional **git-aware `ll`**: `shell/git-aware-ll.bash` recolors immediate child directory names **green** (clean repo) or **yellow** (dirty) when you run `ll` with no arguments—useful under `~/workstation`. Add to `~/.bashrc`:

```bash
[[ -f ~/workstation/shell/git-aware-ll.bash ]] && . ~/workstation/shell/git-aware-ll.bash
```

---

## Scoop CLI tools

Install everything from the JSON (keeps the list in sync): see **`apps/scoop-packages.md`** for one-liners and what each tool does.

| Tool           | Typical use                                          | Docs                                                        |
| -------------- | ---------------------------------------------------- | ----------------------------------------------------------- |
| `rg` (ripgrep) | Fast recursive search                                | `rg --help`                                                 |
| `fd`           | Find files by name                                   | `fd --help`                                                 |
| `fzf`          | Fuzzy finder (often paired with shell history)       | [junegunn/fzf](https://github.com/junegunn/fzf)             |
| `bat`          | `cat` with paging and syntax highlight               | `bat --help`                                                |
| `eza`          | Modern `ls`                                          | `eza --help`                                                |
| `delta`        | Git diff pager (configure in `gitconfig`)            | [dandavison/delta](https://github.com/dandavison/delta)     |
| `jq` / `yq`    | JSON / YAML (and more) in the shell                  | `jq --help`, `yq --help`                                    |
| `pandoc`       | Convert Markdown / docx / PDF, etc.                  | [pandoc.org](https://pandoc.org/)                           |
| `gh`           | GitHub from CLI (`gh auth login` once)               | [cli.github.com](https://cli.github.com/)                   |
| `git-lfs`      | Large files in Git                                   | [git-lfs.com](https://git-lfs.com/)                         |
| `lazygit`      | Terminal UI for Git                                  | `lazygit --help`                                            |
| `zoxide`       | `z` / `zi` directory jumper (initialized in profile) | [ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide) |
| `rclone`       | Sync and mount cloud/NAS (`rclone config`)           | [rclone.org](https://rclone.org/docs/)                      |
| `scoop-search` | Search Scoop manifests from the terminal              | `scoop-search --help`                                       |
| `gsudo`        | Run a single elevated command                        | `gsudo --help`                                              |
| `fastfetch`    | Neofetch-style system info                           | `fastfetch --help`                                          |
| `dust`         | Disk usage tree                                      | `dust --help`                                               |
| `glow`         | Render Markdown in terminal                          | `glow --help`                                               |
| `wget`         | Download URLs / scripts                              | `wget --help`                                               |
| `hyperfine`    | Benchmark shell commands                             | `hyperfine --help`                                          |
| `just`         | Task runner (`justfile`)                             | [github.com/casey/just](https://github.com/casey/just)       |
| `sd`           | Find/replace (simple `sed`-style)                    | `sd --help`                                                 |
| `tldr`         | Short examples for CLI tools (package **tealdeer**)  | `tldr --help`                                               |


---

## Media


| Tool                             | Role                                     | Notes                                                                               |
| -------------------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------- |
| **PotPlayer** (winget)           | Primary player                           | Broad codecs / UI                                                                 |
| **mpv** (binary under `tools\mpv\`; config in **`dotfiles\mpv-config`**; bootstrapped by `mpv-config/install.ps1` via main installer) | Scripted/HDR player | [mpv-config](https://github.com/hedglen/workstation/tree/master/mpv-config) - HDR, shaders, scripts; legacy [hedglen/mpv-config](https://github.com/hedglen/mpv-config) may be archived |
| **yt-dlp** + **FFmpeg** (winget) | Download and remux                       | Also used by `ytdl` / `dl` wrapper; global CLI config is **`projects/ytdl/appdata-config`** → `%APPDATA%\yt-dlp\config` via **`install.ps1`** |
| **Audirvana Origin** (manual)    | Primary local music player               | Not on winget — installer from [audirvana.com](https://audirvana.com/origin/); license in Proton Pass |
| **Qobuz**                        | Streaming client                         | Login in app                                                                        |
| **ShareX**                       | Screenshots, screen recording, workflows | Hotkeys in ShareX settings                                                          |
| **Bandicut**                     | Lossless-ish cuts                        | Paid; good for quick trims                                                          |
| **HandBrake**                    | Transcode to H.264/H.265/AV1             | Presets + queue                                                                     |
| **OBS Studio**                   | Recording / streaming                    | Scenes, sources, NVENC/AMD encoders                                                 |
| **ScreenToGif**                  | Short GIF captures                       | Editor built in                                                                     |
| **MediaInfo**                    | Container/codec readout                  | Right-click files or open GUI                                                       |
| **XnViewMP**                     | Image browser / light edit               | Batch rename, formats                                                               |


---

## Files, images, PDFs


| Tool                    | Role                                                             |
| ----------------------- | ---------------------------------------------------------------- |
| **Directory Opus**      | Main file manager — see [directory-opus.md](./directory-opus.md) |
| **Everything**          | Instant filename search across NTFS                              |
| **WizTree**             | Disk usage by folder (fast on NTFS)                              |
| **Bulk Rename Utility** | Pattern-based renames (winget)                                   |
| **DupeGuru**            | Find duplicate files                                             |
| **ImageGlass**          | Fast image viewer                                                |
| **SumatraPDF**          | Lightweight PDF reader                                           |
| **calibre**             | E-books                                                          |
| **LibreOffice**         | Office documents                                                 |
| **ModernCSV**           | Spreadsheet / CSV focused editor                                 |


---

## Dev and editors


| Tool                                    | Role                                                         |
| --------------------------------------- | ------------------------------------------------------------ |
| **Git**                                 | Version control; aliases in `git/.gitconfig`        |
| **GitHub CLI** (`gh`)                   | PRs, clones, API — `gh auth login`                           |
| **GitHub Desktop**                      | Git/GitHub GUI — clone, commit, PRs without the command line (winget) |
| **VS Code** / **Cursor**                | Editors; extensions from `vscode/extensions.txt`; **Claude** desktop (winget) for Anthropic chat |
| **Zed** / **Sublime Text 4**            | GUI editors (winget): Zed — fast Rust-based with AI/collab; Sublime — polished, commercial |
| **Neovim** (`nvim`) / **Helix** (`hx`)  | Terminal modal editors (Scoop); Helix ships LSP + tree-sitter built in, no plugins needed |
| **PowerShell 7**                        | Default shell in Windows Terminal / WezTerm                  |
| **Windows Terminal** / **WezTerm**      | **WezTerm** (`wezterm/wezterm.lua`), tab order: **system** (drives, IP, update runbook in the right pane); **wsl** with right-pane helper (`wezterm/wsl-helper.sh`); dedicated **grok**, **claude**, **codex**, and **vibe** AI tabs (vibe's right pane live-checks CLI version + auth); **git** (workspace-folder clean/dirty + commit checklist, refreshes); **toolbelt** (Scoop CLI cheat sheet in the right pane). **Windows Terminal**: linked `windows-terminal/settings.json`. |
| **Rio** / **Alacritty** / **winghostty** | Terminal emulators on trial (winget) — WezTerm stays primary until one earns its keep |
| **Node.js LTS**                         | `node`, `npm`                                                |
| **Python Launcher** (`py`)              | Picks installed Python                                       |
| **AutoHotkey**                          | Hotkeys — `autohotkey/main.ahk`                     |
| **uv**                                  | Fast Python package/venv manager (winget)                    |


---

## System, privacy, hardware


| Tool                                          | Role                                             |
| --------------------------------------------- | ------------------------------------------------ |
| **PowerToys**                                 | FancyZones, PowerToys Run, keyboard remaps, etc. |
| **Sysinternals**                              | `procexp`, `autoruns`, `dbgview`, …              |
| **HWiNFO** / **CrystalDiskInfo**              | Sensors, SMART                                   |
| **MSI Afterburner**                           | GPU OC / overlay (with Rivatuner as applicable)  |
| **FanControl**                                | Custom fan curves                                |
| **AOMEI Partition Assistant**                 | Partitions / disks                               |
| **TranslucentTB**                             | Taskbar transparency                             |
| **StartAllBack**                              | Taskbar / Start styling (paid)                   |
| **EarTrumpet**                                | Per-app volume in tray                           |
| **Proton VPN / Drive / Pass / Authenticator** | VPN, cloud, passwords, 2FA                       |
| **Signal**                                    | Messaging (winget)                               |


---

## Cloud, sync, downloads


| Tool                                | Role                                                                  |
| ----------------------------------- | --------------------------------------------------------------------- |
| **Google Drive** / **pCloud Drive** | Cloud sync clients                                                    |
| **Internet Download Manager**       | HTTP download manager (paid, winget)                                |
| **JDownloader**                     | Host / bulk downloads (winget `AppWork.JDownloader`)                  |
| **rclone**                          | Scriptable sync (Scoop or PATH) — `rclone config`, `rclone sync`      |
| **LocalSend**                       | AirDrop-like LAN share                                                |


---

## Productivity and misc


| Tool                                          | Role                                        |
| --------------------------------------------- | ------------------------------------------- |
| **Tesseract OCR** (installer)                 | OCR engine (winget); used by other tools    |
| **Chrome** / **Firefox Nightly**              | Browsers (winget)                           |
| **Steam**                                     | Games (winget)                              |
| **Adobe Creative Cloud**                      | Creative suite (winget)                     |
| **Logitech G HUB** / **Corsair iCUE**         | Peripherals                                 |
| **PawnIO**                                    | Low-level hardware helper (niche)           |


---

## Runtimes and prerequisites

DotNet desktop runtimes, VC++ redistributables, Windows App Runtime, App Installer, and similar entries in `winget-packages.json` exist so **applications install cleanly**, not for daily direct use.

---

## Manual installs (not in winget list)

See the README **Manual Installs** section (currently Battle.net). **JDownloader** is in `winget-packages.json` (`AppWork.JDownloader`); manual steps there are only for alternate installers. **Directory Opus** is licensed separately; setup notes are in [directory-opus.md](./directory-opus.md).

---

## Related

- [Workstation README](https://github.com/hedglen/workstation/blob/master/README.md) — bootstrap, profile tables, AHK, Terminal, VS Code, Git
- [winget-packages.md](https://github.com/hedglen/workstation/blob/master/apps/winget-packages.md) / [scoop-packages.md](https://github.com/hedglen/workstation/blob/master/apps/scoop-packages.md) — manifest blurbs
- [**workstation-setup.md**](./workstation-setup.md) — rebuild / verification runbook
- [**workstation-layout.md**](./workstation-layout.md) — folder tree
- [mpv-config](https://github.com/hedglen/workstation/tree/master/mpv-config) - bundled mpv configuration (legacy [hedglen/mpv-config](https://github.com/hedglen/mpv-config) may be archived)
