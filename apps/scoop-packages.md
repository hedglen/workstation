# `scoop-packages.json`

Portable CLI tools from the **Scoop `main` bucket**, plus `lazygit` from **extras** (`install.ps1` adds that bucket automatically). The manifest is JSONC — categorized with `//` comments — which PowerShell's `ConvertFrom-Json` reads fine. Install [Scoop](https://scoop.sh/) first (`irm get.scoop.sh | iex`), then install everything from this folder with:

```powershell
Set-Location $HOME\workstation\dotfiles\apps
scoop bucket add extras
$pkgs = (Get-Content .\scoop-packages.json -Raw | ConvertFrom-Json).packages
scoop install @pkgs
```

Or install packages individually. These complement GUI and runtime apps in **`winget-packages.json`**. **`install.ps1`** runs **get.scoop.sh** if Scoop is missing, then installs this list. See **`winget-packages.md`** for the winget list.

---

## Packages

| Package | What it does | Example use |
|--------|----------------|-------------|
| **bat** | `cat` with syntax highlighting, paging, and Git integration. | Read a config or log with line numbers: `bat README.md` |
| **delta** | Rich diffs in the terminal (often wired into Git). | `git diff` with side-by-side syntax highlighting after configuring Git to use `delta` |
| **dust** | Disk usage by folder, fast and readable tree. | Find what is eating space: `dust` or `dust C:\Projects` |
| **eza** | Modern `ls` with colors, icons, git status, tree. | `eza -la --git` in a repo |
| **fastfetch** | System info summary in the terminal (neofetch-style). | Quick “what machine is this?” in a new shell |
| **fd** | Fast, user-friendly `find` for files by name. | `fd '*.rs'` or `fd config` under the current tree |
| **fzf** | Fuzzy finder for files, history, anything piped in. | `fzf` after `fd`; Ctrl+R style history in shells that integrate it |
| **gh** | Official GitHub CLI: repos, PRs, issues, Actions. | `gh pr checkout 42`, `gh repo clone org/name` |
| **git-lfs** | Git extension for large binary assets (stores pointers in Git). | Game assets, datasets, large images in a tracked repo |
| **glow** | Renders Markdown in the terminal. | `glow NOTES.md` or `README.md` without opening a browser |
| **gsudo** | Sudo-style elevation for Windows commands and shells. | `gsudo notepad C:\Windows\System32\drivers\etc\hosts` |
| **hyperfine** | Benchmarks shell commands (warmup, multiple runs, stats). | Compare two tools: `hyperfine 'fd foo' 'rg --files \| findstr foo'` |
| **jq** | Query and transform JSON on the command line. | `curl -s API | jq '.items[].id'` |
| **just** | Command runner / mini task runner (like a focused Makefile). | `just test` from a repo with a `justfile` |
| **lazygit** | Full-screen TUI for Git staging, commits, branches, logs. | Quick interactive Git when you do not want the full GUI |
| **pandoc** | Converts between Markdown, Word, PDF, HTML, LaTeX, and more. | `pandoc report.md -o report.pdf` |
| **rclone** | Syncs and mounts cloud storage (S3, Drive, Dropbox, etc.). | `rclone sync remote:bucket D:\backup` |
| **ripgrep** (`rg`) | Extremely fast recursive text search with regex and filtering. | `rg 'TODO' --type rust` across a codebase |
| **scoop-search** | Search Scoop manifests from the terminal. | `scoop-search ffmpeg` or `scoop-search git` |
| **sd** | Intuitive find-and-replace (often easier than `sed` for simple jobs). | `sd 'old' 'new' **/*.txt` |
| **tealdeer** | Local **tldr** client: short practical examples for CLI tools. | `tldr tar` then `tldr --update` occasionally to refresh pages |
| **wget** | Downloads files and mirrors sites from the command line. | `wget URL -O file.zip` in scripts or recovery environments |
| **yq** | Query and edit YAML, JSON, XML, CSV from the CLI (like `jq` for YAML). | `yq '.spec.replicas' deployment.yaml` |
| **zoxide** | Remembers directories you use; jump by fuzzy name (`z`, `zi`). | `z proj` jumps to a frequently used `...\projects\foo` path |

---

## Note on **tealdeer**

The Scoop package name is `tealdeer`; the command you run is **`tldr`**. Refresh cached cheat sheets with **`tldr --update`** (wording may vary slightly by version).
