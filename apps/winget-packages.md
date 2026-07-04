# `winget-packages.json`

Companion notes for **`winget-packages.json`** in this folder (`dotfiles/apps`). Import from the repo root or `apps` with:

```powershell
winget import "$HOME\workstation\dotfiles\apps\winget-packages.json" --accept-package-agreements
```

The JSON groups packages roughly as: **dev toolchain → .NET / Windows platform → WSL → browsers → media → files & cloud → productivity → Proton / Signal → hardware → desktop shell & AI tools → creative / games**. **`install.ps1`** imports this file, then installs **Scoop** (get.scoop.sh) and **`apps/scoop-packages.json`** unless you pass **`-NoScoop`**. Keep **only** this copy in the repo (no duplicate manifests under `%USERPROFILE%\Documents`). See **`scoop-packages.md`** for the Scoop CLI list.

---

## Dev toolchain and prompt

| ID | What it does | Example use |
|----|----------------|-------------|
| **Git.Git** | Distributed version control. | Clone, branch, commit any software project |
| **Microsoft.PowerShell** | PowerShell 7+ on Windows. | Scripts and daily terminal when you want `pwsh` features |
| **Microsoft.VisualStudioCode** | Lightweight extensible code editor. | General coding, debugging with extensions |
| **Notepad++.Notepad++** | Fast editor with syntax highlighting and plugins. | Quick edits, logs, XML/JSON without a full IDE |
| **Codeium.Windsurf** | AI-assisted IDE (Codeium). | Agentic editing when you use Windsurf as primary IDE |
| **AutoHotkey.AutoHotkey** | Hotkeys, text expansion, window automation. | Global shortcuts, remaps, simple GUI automation |
| **OpenJS.NodeJS.LTS** | Long-term-support Node.js (JavaScript + npm). | Web frontends, tooling, `npx` utilities |
| **Python.Python.3.14** | CPython 3.14 (system-wide install). | Base interpreter for venvs, scripts, and the `python` command |
| **Python.Launcher** | `py` launcher to pick installed Python versions. | Run scripts when multiple Pythons are installed |
| **astral-sh.uv** | Extremely fast Python package/venv manager. | `uv pip install`, `uv venv`, `uvx tool` without waiting on pip |
| **DenoLand.Deno** | JavaScript/TypeScript runtime (V8). | Scripts, small servers, modern TS without a separate build step |
| **JanDeDobbeleer.OhMyPosh** | Themed, informative shell prompts. | Git-aware path, duration, and icons in PowerShell or other shells |
| **DEVCOM.JetBrainsMonoNerdFont** | Monospace font with icon glyphs for terminals. | Oh My Posh and terminals render icons without tofu |

---

## .NET and Windows platform runtimes

| ID | What it does | Example use |
|----|----------------|-------------|
| **Microsoft.DotNet.DesktopRuntime.6–10** | .NET desktop runtime for WinForms/WPF per major version. | Run apps that ask for “.NET 8 Desktop Runtime” |
| **Microsoft.DotNet.Runtime.6/8/9** | Console / ASP.NET .NET runtime (non-desktop). | Apps that need a specific .NET major without the desktop pack |
| **Microsoft.VCRedist.2015+.x86/x64** | Visual C++ runtime for native Windows apps. | Avoid “VCRUNTIME140.dll missing” on a fresh install |
| **Microsoft.VCLibs.14** / **Desktop.14** | UWP/WinUI dependency libraries. | Store-style or WinUI apps that expect these packages |
| **Microsoft.AppInstaller** | Windows Package Manager / install infrastructure. | Keep winget and related install UX current |
| **Microsoft.UI.Xaml.2.8** | WinUI 2 XAML framework. | Apps that fail without the right UI XAML runtime |
| **Microsoft.WindowsAppRuntime.1.8** | Windows App SDK runtime for WinUI 3 apps. | Newer packaged desktop apps |

---

## WSL

| ID | What it does | Example use |
|----|----------------|-------------|
| **Microsoft.WSL** | Windows Subsystem for Linux. | Run Linux distros and dev tooling without a full VM |
| **Canonical.Ubuntu.2404** | Ubuntu 24.04 LTS as a WSL distribution. | Default Linux environment for `bash`, Docker-from-WSL, etc. |

---

## Browsers

| ID | What it does | Example use |
|----|----------------|-------------|
| **Google.Chrome.EXE** | Google Chrome (EXE installer id in winget). | Primary browser |
| **Mozilla.Firefox** | Firefox. | Different engine for testing or privacy-focused browsing |

---

## Media: playback, capture, download

| ID | What it does | Example use |
|----|----------------|-------------|
| **Daum.PotPlayer** | Full-featured video/audio player. | Broad codecs and filters without extra plugins |
| **shinchiro.mpv** | mpv player (shinchiro build). | Scriptable playback; `dotfiles/mpv-config` is junctioned in as its portable config |
| **VideoLAN.VLC** | Plays nearly anything, streams, converts. | Fallback player and quick network-stream checks |
| **ShareX.ShareX** | Screenshots, recording, uploads, workflows. | Region capture → clipboard or host in one shortcut |
| **BandicamCompany.Bandicut** | Video cutter/joiner. | Trim clips without a full editor |
| **yt-dlp.FFmpeg** | FFmpeg packaged for yt-dlp workflows. | Encoding/decoding for downloads and tools that call ffmpeg |
| **yt-dlp.yt-dlp** | Downloads video/audio from many sites (CLI). | Archive a stream or grab audio: `yt-dlp URL` |
| **FlorianHeidenreich.Mp3tag** | Tag editor for audio files. | Batch-fix album/artist tags and cover art |
| **XnSoft.XnViewMP** | Image browser, viewer, batch operations. | Fast review of large photo folders |

---

## Files, archives, media tools, cloud, download managers

| ID | What it does | Example use |
|----|----------------|-------------|
| **voidtools.Everything** | Instant filename search on NTFS. | Find any file by partial name in milliseconds |
| **GPSoftware.DirectoryOpus** | Advanced dual-pane file manager (commercial). | Heavy file operations and layouts |
| **M2Team.NanaZip** | 7-Zip–based archiver with modern UI. | `.7z`, `.zip`, `.rar` extract and create |
| **TGRMNSoftware.BulkRenameUtility** | Rule-based mass rename. | Fix `IMG_0001` sequences or episode names |
| **AntibodySoftware.WizTree** | Disk usage treemap / fast size scan. | Largest folders on a full drive |
| **MediaArea.MediaInfo.GUI** | Technical metadata for media files. | Codec, bitrate, HDR — debug playback issues |
| **HandBrake.HandBrake** | Video transcoding with presets. | Compress for phone/tablet (where legal for your source) |
| **DuongDieuPhap.ImageGlass** | Lightweight modern image viewer. | Default “open image” handler |
| **NickeManarin.ScreenToGif** | Record to animated GIF with editor. | Short UI demos for docs or bug reports |
| **SumatraPDF.SumatraPDF** | Fast PDF (and some ebook) viewer. | Open PDFs without a heavy suite |
| **OBSProject.OBSStudio** | Streaming and screen recording. | YouTube/Twitch, tutorials, multi-source scenes |
| **Google.GoogleDrive** | Google Drive desktop client. | Sync Drive folders locally |
| **pCloudAG.pCloudDrive** | pCloud virtual drive. | Cloud folder as a drive letter |
| **Tonec.InternetDownloadManager** | Download accelerator (commercial). | Large files, segmented downloads, browser hooks |
| **AppWork.JDownloader** | Download manager for hosts and playlists. | Bulk downloads from file hosts |
| **qBittorrent.qBittorrent** | Open-source BitTorrent client. | Linux ISOs and other legitimate torrents |

---

## Knowledge, office, desktop utilities

| ID | What it does | Example use |
|----|----------------|-------------|
| **Obsidian.Obsidian** | Local-first Markdown notes and plugins. | Second brain, linked project notes |
| **calibre.calibre** | E-book library and conversion. | Manage EPUB/PDF, send to e-readers |
| **EDRLab.Thorium** | Accessible EPUB 3 reader (Readium). | Reflowable books with screen-reader support |
| **TheDocumentFoundation.LibreOffice** | Office suite (Writer, Calc, Impress, …). | Documents/spreadsheets without Microsoft 365 |
| **Foxit.PhantomPDF.Subscription.MSI** | Foxit PDF Editor (subscription). | Edit, annotate, and fill PDFs beyond a viewer |
| **File-New-Project.EarTrumpet** | Per-app volume in the tray. | Quiet one noisy app without muting everything |
| **LocalSend.LocalSend** | LAN file send between devices. | Phone ↔ PC on same Wi‑Fi |
| **UB-Mannheim.TesseractOCR** | OCR engine; often used by other tools. | Text extraction from scans |
| **DupeGuru.DupeGuru** | Duplicate file finder. | Reclaim space in messy download folders |
| **PFOJEnterprisesLLC.ModernCSV** | Spreadsheet editor tuned for large CSV. | When Excel chokes on huge files |
| **Qobuz.Qobuz** | Hi-res streaming desktop app. | Lossless streaming with a Qobuz subscription |
| **namazso.PawnIO** | Driver/tooling for specific hardware experiments. | Only when you know you need Pawn IO on that PC |

---

## Privacy and messaging (Proton + Signal)

| ID | What it does | Example use |
|----|----------------|-------------|
| **Proton.ProtonVPN** | VPN client for Proton. | Untrusted Wi‑Fi, geo/IP privacy |
| **Proton.ProtonDrive** | Encrypted cloud storage client. | Sync files in the Proton ecosystem |
| **Proton.ProtonPass** | Password manager. | Vault, autofill, secure notes |
| **Proton.ProtonAuthenticator** | TOTP / 2FA from Proton. | Second factor for accounts |
| **OpenWhisperSystems.Signal** | Encrypted chat and calls. | Personal messaging off SMS |

---

## Hardware, monitoring, peripherals

| ID | What it does | Example use |
|----|----------------|-------------|
| **REALiX.HWiNFO** | Sensors, clocks, detailed hardware report. | Thermals, RAM/GPU verification |
| **CrystalDewWorld.CrystalDiskInfo** | S.M.A.R.T. health for disks. | SSD wear before failure |
| **Guru3D.Afterburner** | GPU overclocking and on-screen stats. | Fan curves, FPS overlay while gaming |
| **Rem0o.FanControl** | Fan curves for many boards/GPUs. | Balance noise and cooling |
| **AOMEI.PartitionAssistant** | Partition resize, copy, migrate (edition-dependent). | When Disk Management is not enough |
| **Devolutions.UniGetUI** | GUI for winget and other package sources. | Browse installs without memorizing IDs |
| **Microsoft.Sysinternals.Suite** | Process Explorer, Autoruns, TCPView, etc. | Deep Windows troubleshooting |
| **Logitech.GHUB** | Drivers and lighting for Logitech G gear. | **Install only on PCs with supported Logitech hardware** |
| **Corsair.iCUE.5** | RGB and device control for Corsair. | **Install only on PCs with Corsair devices** |

---

## Desktop shell, terminals, AI desktop apps

| ID | What it does | Example use |
|----|----------------|-------------|
| **StartIsBack.StartAllBack** | Taskbar and Start styling for Windows 11 (commercial). | Familiar taskbar/Start layout |
| **Microsoft.WindowsTerminal** | Tabbed host for PowerShell, CMD, WSL, etc. | One window, multiple profiles |
| **Microsoft.PowerToys** | FancyZones, PowerRename, Color Picker, Keyboard Manager, … | Tiling, bulk rename in Explorer, remaps |
| **wez.wezterm** | GPU terminal with Lua configuration. | Splits, themes, advanced terminal users |
| **CharlesMilette.TranslucentTB** | Transparent or blurred taskbar. | Visual desktop tweak |
| **Ollama.Ollama** | Run local LLMs. | Offline models and private inference |
| **Anysphere.Cursor** | VS Code–style editor with AI features. | Daily coding with AI assistance |
| **Anthropic.Claude** | Official Claude desktop app. | Chat outside the browser |

---

## Creative and games

| ID | What it does | Example use |
|----|----------------|-------------|
| **Adobe.CreativeCloud** | Adobe installer hub (subscription). | Photoshop, Premiere, etc. |
| **Valve.Steam** | Store, library, updates, multiplayer. | PC gaming catalog |

---

## Tips

- **Licenses:** Opus, IDM, StartAllBack, Adobe, and others assume you **own a license** on that machine.
- **Hardware:** Skip or uninstall GHUB/iCUE on PCs without matching gear.
- **Overlap:** Multiple browsers and media players are intentional for some setups; trim the JSON on minimal installs if you want faster `winget import`.
- **Single source:** Do not maintain a second `winget-packages.json` under Documents or elsewhere; edit **this** file and run `install.ps1` / `maintenance\update.ps1`.
