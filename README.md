# dotfiles

> Personal Windows dotfiles — configs, tools, and a one-command machine bootstrap.

---

## 🖥️ Related

- **[README.md](README.md)** — root bootstrap guide for this repo (you are here)
- **[docs/README.md](docs/README.md)** — index of workstation setup/layout/tools docs
- **[docs/clean-reinstall-README.md](docs/clean-reinstall-README.md)** — wipe-and-rebuild checklist for clean Windows reinstalls
- **[scripts/README.md](scripts/README.md)** — workstation utility scripts and health-check usage
- **[wsl/README.md](wsl/README.md)** — WSL shell sync, tooling, and GitHub auth notes
- **[mpv-config/README.md](mpv-config/README.md)** — mpv configuration/features and install behavior
- **[notes/README.md](notes/README.md)** — notes area structure and organization
- **[corsair/README.md](corsair/README.md)** — Corsair/Scimitar helper scripts and usage
- **[projects/media-organizer/README.md](projects/media-organizer/README.md)** — media organizer project docs
- **[projects/ytdl/README.md](projects/ytdl/README.md)** — ytdl wrapper project docs

---

## ⚡ Fresh Machine Setup

Use this on a **brand-new Windows PC** before you do anything else. Order matters: Git must exist so the bootstrap can clone repos; `winget` must work so apps can install.

**Username:** Nothing here is tied to the name `rjh`. The installer and profile use **`$HOME\workstation\...`** (same as **`%USERPROFILE%\workstation\...`** on disk). If your account is `alex`, you get `C:\Users\alex\workstation\...`. Forks and docs that still show `C:\Users\rjh\...` are just the author’s machine—substitute your profile path or use `$HOME` in PowerShell.

### 1. Open PowerShell

Use **Windows PowerShell** or **PowerShell 7** (either is fine for the steps below). You do not need admin for Git or the remote install line; you will need admin later if you want Windows tweaks applied automatically (the installer will tell you).

### 2. Confirm `winget` (Windows Package Manager)

The installer uses `winget` to import your app list. On Windows 11 it is usually already available.

```powershell
winget --version
```

If that fails:

- **Windows 11:** Install pending updates, or install [App Installer](https://apps.microsoft.com/detail/9nblggh4nns1) from the Microsoft Store.
- **Windows 10:** Install **App Installer** from the Store (same link), or see [Microsoft’s winget install docs](https://learn.microsoft.com/windows/package-manager/winget/).

### 3. Install Git (required before the one-liner)

The remote bootstrap runs `git clone`. Install Git first, then **open a new terminal** so `git` is on your `PATH`.

**Recommended (matches the rest of your stack):**

```powershell
winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
```

**Alternative:** Download and run the installer from [git-scm.com/download/win](https://git-scm.com/download/win). Use the default options unless you know you want something different; ensure **“Git from the command line and also from 3rd-party software”** (or equivalent) is selected so PowerShell can find `git`.

**Verify:**

```powershell
git --version
```

You should see something like `git version 2.x.x`.

### 4. Run the bootstrap (one command)

```powershell
irm https://raw.githubusercontent.com/hedglen/dotfiles/master/install.ps1 | iex
```

This will:

1. Clone this repo to `$HOME\workstation\dotfiles` (i.e. `%USERPROFILE%\workstation\dotfiles`)
2. Clone **`hedglen-profile`**. Create **`workstation\tools`** if missing. Ensure **`dotfiles\scripts`** and **`dotfiles\projects`** exist; add **junctions** **`workstation\scripts`** → **`dotfiles\scripts`** and **`workstation\projects`** → **`dotfiles\projects`** when those paths are not already taken (legacy-friendly paths). Personal notes: **`notes/`** in this repo. Restore workstation-root docs: **`CLAUDE.md`** (from **`claude/CLAUDE.md`**) and the **`WORKSTATION-SETUP.md`** stub.
3. Install apps: **`winget install`** per package ID from **`apps/winget-packages.json`** (JSONC with category comments — no `winget import`); then **Scoop** via **get.scoop.sh** (unless **`-NoScoop`**), the **extras** bucket, and **`scoop install`** from **`apps/scoop-packages.json`** (see **`apps/winget-packages.md`** / **`apps/scoop-packages.md`**). Then the **Claude Code CLI** (native installer — auto-updates) when `claude` is not on PATH.
4. Create Python **`.venv`**s for **`projects\media-organizer`**, **`projects\ytdl`**, and **`tools\transcribe-env`** (Whisper deps — large download) from their `requirements` files (uses **`uv`** when available, else **`py`** + pip; skipped by **`-NoPythonProjects`** or **`-ConfigsOnly`**).
5. Apply Windows tweaks (requires admin)
6. Symlink all configs to their correct locations (incl. **`claude/settings.json`** → `~/.claude/settings.json`)
7. Install all VS Code + Cursor extensions
8. Install CaskaydiaCove Nerd Font
9. Junction `tools\mpv\portable_config` to `dotfiles\mpv-config` for mpv (when the installer configures mpv)
10. Register AutoHotkey on startup
11. Provision WSL: **`wsl/setup.sh`** (apt tools, zsh + oh-my-zsh + Powerlevel10k, tracked `.zshrc`/`.p10k.zsh`, uv, claude/codex CLIs) and **`wsl/setup-crons.sh`** (cron jobs). Only remaining WSL manual step: `gh auth login`.

**Guides and runbook:** start at **[`docs/README.md`](docs/README.md)** (workstation layout, setup, tools, Opus).

---

## 🗂️ What's In Here

```text
dotfiles/
├── install.ps1                    ← bootstrap script
├── lib/                           ← shared helpers for install/update/health
│   ├── common.ps1                 ← loggers + Test-IsAdmin
│   ├── config-links.ps1           ← THE config map + loader-aware linker
│   ├── startup-policy.ps1         ← HKCU Run cleanup policy
│   ├── fonts.ps1                  ← Nerd Font install
│   ├── extensions.ps1             ← VS Code/Cursor extension sync
│   └── python-projects.ps1        ← uv-first venv creation
├── claude/
│   ├── CLAUDE.md                  ← workstation-root Claude Code context (copied to workstation\)
│   └── settings.json              ← ~/.claude/settings.json (symlinked)
├── autohotkey/
│   └── main.ahk                   ← hotkeys, app launchers, text expanders
├── powershell/
│   └── profile.ps1                ← prompt, aliases, helper functions
├── shell/
│   └── git-aware-ll.bash          ← optional Git Bash `ll`: colors git subdirs green (clean) / yellow (dirty); source from `~/.bashrc`
├── oh-my-posh/
│   └── hedglab.omp.json           ← custom OMP theme (Neon Dark–style segments)
├── wezterm/
│   ├── wezterm.lua                ← gui-startup tabs: system, coding, git, wsl, claude, codex
│   └── wsl-helper.sh              ← right pane helper for the WezTerm wsl tab (quick jumps + gh notes)
├── wsl/
│   ├── .zshrc                     ← WSL shell aliases, workstation helpers
│   ├── .p10k.zsh                  ← WSL Powerlevel10k prompt
│   ├── setup.sh                   ← idempotent WSL provisioning (apt, zsh/omz/p10k, uv, claude/codex)
│   ├── setup-crons.sh             ← WSL cron jobs (run by install.ps1)
│   └── README.md                  ← WSL setup notes + gh auth
├── vscode/
│   ├── settings.json              ← editor settings, font, theme
│   └── extensions.txt             ← extension list for auto-install
├── windows-terminal/
│   └── settings.json              ← Neon Dark terminal scheme, Nerd Font, keybindings
├── windows/
│   └── tweaks.ps1                 ← privacy, power, explorer tweaks
├── docs/
│   ├── README.md                  ← index to workstation guides
│   ├── workstation-setup.md       ← rebuild / verification runbook
│   ├── workstation-layout.md      ← canonical folder layout + junctions
│   ├── workstation-tools.md       ← app map + PowerShell helpers
│   └── directory-opus.md          ← Directory Opus setup
├── scripts/
│   ├── workstation-health.ps1      ← quick layout + tooling check
│   ├── transcribe.py / .ps1       ← media helpers (see scripts/README.md)
│   ├── python/                     ← cross-platform CLI helpers
│   └── README.md
├── projects/
│   ├── media-organizer/           ← orgmed / orgmedx (venv created by install.ps1)
│   └── ytdl/                      ← ytdl / dl wrapper (venv + rich); appdata-config → %APPDATA%\yt-dlp\config (install.ps1)
├── mpv-config/                   → bundled mpv Lua/conf; install.ps1 junction → tools\mpv\portable_config
├── notes/
│   ├── README.md                  ← README + personal/tech/work folders
│   ├── personal/
│   ├── tech/
│   └── work/
├── git/
│   └── .gitconfig                 ← aliases, colors, sensible defaults
└── apps/
    ├── winget-packages.json       ← full app list (JSONC, categorized; installed per-ID)
    ├── winget-packages.md         ← what each winget package is for
    ├── scoop-packages.json        ← CLI apps installed via Scoop (auto-installed by install.ps1)
    └── scoop-packages.md          ← what each Scoop package is for
```

---

## 🔧 Install Options

```powershell
# Full install (default)
.\install.ps1

# Only install apps, skip config linking
.\install.ps1 -AppsOnly

# Only link configs, skip app install
.\install.ps1 -ConfigsOnly

# Skip app installation
.\install.ps1 -NoApps

# Skip Scoop only (winget installs still run)
.\install.ps1 -NoScoop

# Skip Python venv setup for media-organizer / ytdl
.\install.ps1 -NoPythonProjects

# Preview what would happen without doing anything
.\install.ps1 -DryRun
```

---

## 🔄 Keeping Up to Date

After initial setup, three commands handle ongoing maintenance (all defined in `powershell/profile.ps1`, and listed in WezTerm tab 1's system pane):

| Command | What it does |
| --- | --- |
| `dots-update` (alias `update-all`) | **Full system update**: git pull, relink configs, VS Code/Cursor extensions, fonts, winget upgrades from the manifest, Scoop install + update, Python venv deps |
| `save-dots` | Commit & push your local changes to GitHub |
| `sync-dots` | Pull latest from GitHub, relink any new configs, install new extensions/fonts (no app upgrades) |

`dots-update` runs `maintenance\update.ps1`, which you can also call directly:

```powershell
.\maintenance\update.ps1
```

Options:

```powershell
.\maintenance\update.ps1 -SkipApps    # pull + relink only, no winget/scoop upgrades
.\maintenance\update.ps1 -SkipDots    # upgrade apps only, skip git pull
.\maintenance\update.ps1 -SkipPython  # skip Python venv dependency updates
.\maintenance\update.ps1 -DryRun      # preview without making changes
```

---

## 💻 PowerShell Profile

### Startup Banner

On every new terminal:

- A multi-color neon cheat sheet lists helper commands (cyan, magenta, **bold red** `ytdl`, sky blue, orange, mint); random quotes use **gold** (`#FFD447`)
- A random quote prints in dim grey underneath

### PSReadLine

- Inline suggestions sourced from command history (shown in blue as you type)
- Press `→` to accept a suggestion

### Prompt

Format: `[USER/ADMIN] HH:MM PS path>`

| Element | Color |
| --- | --- |
| `[USER]` / `[ADMIN]` tag | Neon green |
| Time | Bright green |
| `PS` label | Magenta |
| Current path | Yellow/orange |

### Navigation

| Command | Description |
| --- | --- |
| `c` | `cd C:\` |
| `d` | `cd D:\` |
| `home` | `cd ~` |
| `dots` | `cd $HOME\workstation\dotfiles` |
| `tools` | `cd $HOME\workstation\tools` |
| `psh` | `cd $HOME\workstation\tools\powershell` |

### System Helpers

| Command | Description |
| --- | --- |
| `drives` | All volumes with size and free space |
| `uptime` | Time since last boot (`Xd Xh Xm`) |
| `sysinfo` | OS, uptime, RAM, CPU, user, hostname |
| `users` | Local user accounts |
| `admins` | Local admin group members |
| `startup-list` | All startup entries (registry + startup folder) |
| `startup-find 'pattern'` | Search startup entries by name or path |
| `tasks-user` | Non-Microsoft scheduled tasks |
| `pkillf name` | Force-kill all processes matching name |
| `which name` | Find where a command lives |
| `touch path` | Create an empty file |
| `grep pattern` | Pipeline-friendly `Select-String` wrapper |
| `reload` | Re-source the profile in the current session |
| `save-dots [message]` | Commit & push all dotfile changes to GitHub |

### Aliases

| Alias | Resolves To |
| --- | --- |
| `ll` / `la` | `Get-ChildItem` |
| `open` | `Invoke-Item` |
| `startup-list` | `Get-StartupList` |
| `startup-find` | `Search-Startup` |
| `tasks-user` | `Get-UserTasks` |
| `uptime` | `Get-Uptime` |

### Directory Colors

| Type | Color |
| --- | --- |
| Directories | Soft cyan |
| Executables | Warm yellow |

---

## ⌨️ AutoHotkey

Script: `autohotkey/main.ahk` — loads on startup via registry Run key.

### App Launchers (Win + Key)

| Hotkey | Action |
| --- | --- |
| `Win+T` | Windows Terminal (`wt`) |
| `Win+E` | Directory Opus → File Pilot → Explorer (first found) |
| `Win+B` | **Chrome** (primary browser in `winget-packages.json`) |
| `Win+N` | **Firefox Nightly** (winget) |
| `Win+C` | VS Code (`code`) |

### Window Management

| Hotkey | Action |
| --- | --- |
| `Win+Alt+Left` | Move window to left monitor |
| `Win+Alt+Right` | Move window to right monitor |
| `Win+Alt+F` | Toggle maximize / restore |

### Clipboard

| Hotkey | Action |
| --- | --- |
| `Ctrl+Shift+V` | Paste as plain text (strips formatting) |

### Text Expanders

| Trigger | Expands To |
| --- | --- |
| `@@` | `hedglen@pm.me` |
| `/shrug` | `¯\_(ツ)_/¯` |
| `/check` | `✓` |
| `/arr` | `→` |
| `/date` | Today's date (`YYYY-MM-DD`) |

---

## 🖥️ Windows Terminal

### Keyboard Bindings

| Hotkey | Action |
| --- | --- |
| `Ctrl+T` | New tab |
| `Ctrl+W` | Close tab |
| `Ctrl+Tab` | Next tab |
| `Ctrl+Shift+Tab` | Previous tab |
| `Alt+Shift+D` | Duplicate pane (auto-split) |
| `Alt+Shift+Right` | Split pane right |
| `Alt+Shift+Down` | Split pane down |

### Profiles

| Profile | Status |
| --- | --- |
| PowerShell 7 (pwsh) | Default |
| Windows PowerShell | Available |
| Command Prompt | Hidden |
| Azure Cloud Shell | Hidden |

### Cursor

| Setting | Value |
| --- | --- |
| Shape | Bar (vertical “I”) |
| Blink | On (`cursorBlinking`: `blink` in `windows-terminal/settings.json`; `terminal.integrated.cursorBlinking` in VS Code) |

### Color Schemes

**Neon Dark** (active) — aligned with Sudhan’s [Neon Dark Theme](https://marketplace.visualstudio.com/items?itemName=Sudhan.neondark-theme): near-black base, light text, magenta/cyan/gold accents (see `settings.json` schemes).

| Element | Color |
| --- | --- |
| Background | `#0E0E0E` |
| Foreground | `#E4E4E4` |
| Magenta (keywords) | `#E954FF` / bright `#F4A4FF` |
| Cyan (types) | `#00E8FF` / bright `#66F9FF` |
| Blue (sky) | `#64B5FF` / bright `#A8D4FF` |
| Yellow (strings) | `#FFD447` / bright `#FFE566` |
| Red/pink | `#FF6B8A` |
| Teal/green | `#00E8B5` |
| Cursor | `#FF66EE` |
| Selection | `#3D2560` |

**Neon Blaze** — legacy neon green/purple palette (still in `settings.json` if you switch profile scheme).

**Catppuccin Mocha** — soft pastel dark theme (available, not active)

---

## 🧩 VS Code

### Key Settings

| Setting | Value |
| --- | --- |
| Theme | Neon Dark ([Sudhan.neondark-theme](https://marketplace.visualstudio.com/items?itemName=Sudhan.neondark-theme)) |
| Icons | Material Icon Theme |
| Font | Cascadia Code / Fira Code / Consolas |
| Font size | 14 |
| Ligatures | Enabled |
| Tab size | 4 spaces |
| Format on save | Enabled |
| Auto save | On focus change |
| Minimap | Disabled |
| Sticky scroll | Enabled |
| Ruler | 100 chars |
| Terminal font | CaskaydiaCove Nerd Font |
| Terminal font size | 13 |
| Terminal default | PowerShell |
| Terminal cursor | Line + blink (`terminal.integrated.cursorStyle` / `cursorBlinking`) |

**Cursor:** the same `vscode/settings.json` is symlinked to `%APPDATA%\Cursor\User\settings.json` by `install.ps1` / `update.ps1`, so integrated-terminal options (font, Neon Dark colors, **blinking bar cursor**) apply in Cursor—not only in VS Code.

### Extensions

| Category | Extension |
| --- | --- |
| AI | Claude Code (Copilot + Chat ship built into VS Code) |
| Git | GitLens |
| PowerShell | ms-vscode.powershell |
| Python | ms-python.python (Pylance) |
| Lua | sumneko.lua |
| AutoHotkey | thqby.vscode-autohotkey2-lsp |
| Data/Config | redhat.vscode-yaml, rainbow-csv |
| Formatting | Prettier |
| QoL | Error Lens, Material Icons, Better Comments, Path Intellisense |
| Remote | Remote SSH, Remote Explorer |

---

## 🔀 Git

Config: `git/.gitconfig` — symlinked to `~/.gitconfig` on install.

### Shortcuts (aliases)

Instead of typing full git commands, these short versions work:

| Type this | Instead of |
| --- | --- |
| `git st` | `git status` |
| `git co` | `git checkout` |
| `git br` | `git branch` |
| `git cp` | `git cherry-pick` |
| `git rb` | `git rebase` |
| `git lg` | `git log --oneline --graph --decorate --all` (pretty branch tree) |
| `git ll` | last 20 commits, one line each |
| `git last` | last commit with which files changed |
| `git undo` | undo last commit but keep the changes |
| `git unstage file` | remove a file from staging area |
| `git discard file` | throw away changes to a file |
| `git changed` | list files changed in the last commit |
| `git branches` | list all branches (local + remote) |
| `git stashes` | list all stashes |

### Sensible Defaults

| Setting | Value | What it means |
| --- | --- | --- |
| `defaultBranch` | `main` | New repos start on `main` not `master` |
| `autocrlf` | `input` | Don't mangle line endings on Windows |
| `editor` | `code --wait` | VS Code opens for commit messages |
| `pull.rebase` | `false` | `git pull` merges, doesn't rebase |
| `push.autoSetupRemote` | `true` | First push sets upstream automatically |
| `fetch.prune` | `true` | Auto-delete stale remote branches |
| `diff.colorMoved` | `zebra` | Moved code shows differently in diffs |
| `merge.conflictStyle` | `diff3` | Merge conflicts show the original too |

---

## 🔒 Windows Tweaks

Script: `windows/tweaks.ps1` — run during install (admin required).

**Power:**

- High Performance power plan
- Fast startup disabled
- Sleep on AC disabled
- Hard disk sleep disabled

**Privacy:**

- Telemetry set to 0, DiagTrack & dmwappushservice disabled
- Advertising ID, tailored experiences, activity history disabled
- Location services disabled
- Camera/mic/location denied by default for Store apps

**Xbox / Game Bar:**

- Game DVR, Game Bar, background recording disabled
- Xbox services disabled

**Explorer:**

- File extensions visible
- Hidden files visible
- Opens to This PC (not Quick Access)
- Recent/frequent items in Quick Access disabled

**Start / Search / Taskbar:**

- Bing search in Start disabled
- Cortana disabled
- News & Interests widget disabled
- Suggested/promoted apps disabled

---

## 📦 Apps (winget + Scoop)

**Winget** and **Scoop** lists both live under **`apps/`** and are the only source of truth. Both are **JSONC** (JSON with `//` category comments) parsed by PowerShell — they are installed **per package ID**, not via `winget import`. **`install.ps1`** installs every winget ID, then installs **Scoop** from **get.scoop.sh** if it is missing, adds the **extras** bucket, then **`scoop install`** for every name in `scoop-packages.json`. Use **`-NoScoop`** to skip Scoop entirely while still running winget. **`maintenance/update.ps1`** upgrades winget IDs from the JSON, runs **`scoop update *`**, and refreshes Python venv deps from the `requirements` files. Notes: **`apps/winget-packages.md`**, **`apps/scoop-packages.md`**.

Package-manager split, for deciding where a new tool goes:

- **winget** — GUI apps, runtimes, drivers, anything with an installer or updater service
- **Scoop** — portable single-binary CLI tools (main/extras buckets)
- **pip (venvs)** — Python libraries, pinned per project in `requirements` files; never installed globally

For **how to use** installed apps and profile helpers (not just the install list), see **[`docs/workstation-tools.md`](docs/workstation-tools.md)** in this repo ([on GitHub](https://github.com/hedglen/dotfiles/blob/master/docs/workstation-tools.md)).

| Category | Apps (from `apps/winget-packages.json`) |
| --- | --- |
| **Dev / runtimes** | Git, VS Code, **Notepad++**, Cursor, Claude (desktop), PowerShell 7, Python 3.14 + Python Launcher, **uv**, AutoHotkey, Node.js LTS, JetBrainsMono Nerd Font; .NET SDK 10 + .NET 8/10 runtimes, VC++ redists, VCLibs, App Installer, UI XAML, Windows App Runtime; **WSL** + **Ubuntu** |
| **CLI (Scoop)** | Full list in `apps/scoop-packages.json` — see **`apps/scoop-packages.md`** |
| **Terminal / shell** | Windows Terminal, WezTerm, Oh My Posh (winget) |
| **Browsers** | Chrome, Firefox Nightly |
| **Media** | PotPlayer (primary), mpv (shinchiro build), ShareX, Bandicut, yt-dlp + FFmpeg, Mp3tag, XnViewMP, HandBrake, OBS Studio, MediaInfo, ImageGlass, ScreenToGif, SumatraPDF |
| **File management** | Everything, Directory Opus, NanaZip, Bulk Rename Utility, WizTree |
| **Productivity** | LibreOffice, Foxit PDF Editor, Calibre, LocalSend, EarTrumpet, ModernCSV, DupeGuru, Tesseract OCR, Qobuz, PawnIO |
| **Creative** | Adobe Creative Cloud |
| **Privacy / chat** | Proton VPN, Drive, Pass, Authenticator; Signal |
| **Cloud / downloads** | Google Drive, pCloud Drive; Internet Download Manager, JDownloader, qBittorrent |
| **System / hardware** | HWiNFO, CrystalDiskInfo, MSI Afterburner, FanControl, AOMEI Partition Assistant, Sysinternals, Corsair iCUE 5, Logitech G HUB |
| **Desktop shell** | StartAllBack, PowerToys, TranslucentTB |
| **Games** | Steam |

### Scoop (CLI packages)

**`install.ps1`** installs [Scoop](https://github.com/ScoopInstaller/Install) from **get.scoop.sh** when needed, then `scoop install` for every entry in `apps/scoop-packages.json`. To install or refresh manually:

```powershell
Set-Location "$HOME\workstation\dotfiles\apps"
$pkgs = (Get-Content .\scoop-packages.json -Raw | ConvertFrom-Json).packages
scoop install @pkgs
```

`zoxide` is the usual **z**-style directory jumper (`z`, `zi` after you hook it in your shell). Per-tool notes: **`apps/scoop-packages.md`**.

Many GUI apps and heavy runtimes stay on **winget** (see `apps/winget-packages.json`). The **extras** bucket is added automatically by `install.ps1` (needed for `lazygit`).

#### GitHub CLI (`gh`)

The `gh` binary is **not** logged into GitHub until you authenticate.
Default workflow in this repo is **HTTPS** with GitHub CLI credentials; SSH is optional if you prefer key-based Git.

1. Open PowerShell (or any terminal where `gh` is on your `PATH`).
2. Run:

```powershell
gh auth login
```

3. Follow the prompts: choose **GitHub.com**, preferred protocol (**HTTPS** or **SSH**), and sign in via **browser** or paste a **personal access token**.

After that, `gh repo clone`, `gh pr create`, and other `gh` commands use your account. This is separate from `git`’s own credential helper unless you deliberately use the same method (for example, HTTPS with the same stored token).

##### WSL Note

If you run `gh auth login` inside WSL, install `wslu` first so browser login opens correctly in Windows:

```bash
sudo apt update
sudo apt install -y wslu
gh auth login
```

Recommended WSL answers:

- account: `GitHub.com`
- protocol: `HTTPS`
- authenticate Git with GitHub credentials: `Yes`
- auth method: `Login with a web browser`

If the browser handoff still misbehaves, open [github.com/login/device](https://github.com/login/device) in Windows and enter the one-time code shown by `gh`.

---

## 🔧 Manual Installs

Manual-only apps (not on winget):

### 🎵 Audirvana Origin

- **Download:** [audirvana.com](https://audirvana.com/origin/) — installer requires signing in with your Audirvana account
- **License:** paid (one-time), stored in Proton Pass → Software Licenses
- **Role:** primary local music player

### 🟠 Battle.net

- **Download:** [battle.net installer](https://us.battle.net/download/getBnetInstaller)
- **Install:** Run Battle.net installer, log in with Blizzard account
- **Account:** stored in Bitwarden

Optional alternate installer:

- **JDownloader** is already in `apps/winget-packages.json` as `AppWork.JDownloader`.
- Use manual install only if you prefer the website build or a portable layout.

---

## 🔑 Licenses & Accounts

> ⚠️ **Keys are NOT stored here.** This is a public repo.
> All license keys and passwords are stored in **Proton Pass** under `Software Licenses`.

| App | Type | Where |
| --- | --- | --- |
| Audirvana Origin | Paid license | Proton Pass → Software Licenses |
| StartAllBack | Paid license | Proton Pass → Software Licenses |
| Internet Download Manager | Paid license | Proton Pass → Software Licenses |
| Adobe Creative Cloud | Subscription | Proton Pass → Adobe |
| Corsair iCUE | Free (account optional) | [hedglen@pm.me](mailto:hedglen@pm.me) |
| Proton (VPN/Drive/Pass/Auth) | Subscription | master password — memorize it |
| JDownloader 2 | Free (account optional) | Proton Pass → JDownloader |
| Battle.net / Blizzard | Account | Proton Pass → Blizzard |
| Steam | Account | Proton Pass → Steam |

---

## 🎨 Oh My Posh Theme

Theme: `oh-my-posh/hedglab.omp.json` — diamond **shell** chip, powerline **path** / **git** / **timing** / **exit**, plus a right-aligned **clock**.

| Segment | Colors | Shows |
| --- | --- | --- |
| Shell | Diamond, BG `#E954FF`, text `#0E0E0E` | Nerd icon + shell name (`pwsh`, …) |
| Path | BG `#1B2B38`, text `#66F9FF` | Full path, `/` separators (avoids Powerline PUA glitches in some terminals) |
| Git | BG `#FFD447`, text `#0E0E0E` | Branch (powerline branch icon), status, stash |
| Exec time | BG `#00E8B5`, text `#0E0E0E` | How long the last command took |
| Exit code | Diamond, BG `#FF6B8A`, text `#FFFFFF` | Success or failure of last command |
| Time | Plain, `#64B5FF` | Current time (`HH:mm:ss`), clock icon |

To activate it, add this to your profile (Oh My Posh is already installed via winget):

```powershell
oh-my-posh init pwsh --config "$HOME\workstation\dotfiles\oh-my-posh\hedglab.omp.json" | Invoke-Expression
```

---

## 🎨 Terminal Theme — Neon Dark

CaskaydiaCove Nerd Font is installed automatically by `install.ps1` (step 8). No manual download needed.

The **Neon Dark** scheme (matched to Sudhan’s VS Code [Neon Dark Theme](https://marketplace.visualstudio.com/items?itemName=Sudhan.neondark-theme)) is defined in `windows-terminal/settings.json` and mirrored in `vscode/settings.json` (`terminal.integrated.*` + `workbench.colorCustomizations`) so Windows Terminal and the VS Code integrated terminal stay consistent. **Neon Blaze** remains in `settings.json` if you want the old green-accent look.
