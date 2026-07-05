## WSL Shell Files

This folder tracks the Linux-side shell setup used by the WezTerm `wsl`, `grok`, `claude`, `codex`, and `vibe` tabs.

**Provisioning is automated:** `wsl/setup.sh` idempotently installs the apt tooling, zsh + oh-my-zsh + Powerlevel10k, copies the tracked shell files, and installs uv, yt-dlp, and the claude/codex/grok/vibe CLIs. `dotfiles/install.ps1` runs it during bootstrap (after the distro's first launch has created your user); you can also run it any time from WSL:

```bash
bash "$WIN_HOME/workstation/dotfiles/wsl/setup.sh"
```

The only remaining manual step afterwards is `gh auth login` (see below).

Tracked files:

- `.zshrc`
- `.p10k.zsh`

Live targets inside WSL:

- `~/.zshrc`
- `~/.p10k.zsh`

### What The Tracked `.zshrc` Does

- loads `oh-my-zsh`
- uses `powerlevel10k`
- adds `$HOME/.local/bin` to `PATH` so user installs like `uv` work
- defines `WORKSTATION` from the Windows user profile path
- provides workstation launch helpers for `claude` and `codex`
- adds `fd` as an alias for Ubuntu's `fdfind`
- initializes `zoxide` if installed
- sets `BROWSER=wslview` when `wslu` is installed so browser-based flows from WSL open correctly in Windows

### Keep Tracked And Live Files In Sync

Edit the tracked files first, then copy them into WSL — re-running `wsl/setup.sh` does the copy for you. To copy just the shell files manually:

Set a reusable Windows home mount variable first:

```bash
WIN_HOME="/mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r')"
```

From PowerShell:

```powershell
wsl -e zsh -lc 'WIN_HOME="/mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d "\r")"; cp "$WIN_HOME/workstation/dotfiles/wsl/.zshrc" ~/.zshrc'
wsl -e zsh -lc 'WIN_HOME="/mnt/c/Users/$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d "\r")"; cp "$WIN_HOME/workstation/dotfiles/wsl/.p10k.zsh" ~/.p10k.zsh'
```

From WSL:

```bash
cp "$WIN_HOME/workstation/dotfiles/wsl/.zshrc" ~/.zshrc
cp "$WIN_HOME/workstation/dotfiles/wsl/.p10k.zsh" ~/.p10k.zsh
exec zsh -l
```

### Recommended WSL Tooling

`wsl/setup.sh` installs everything this shell config expects (ripgrep, fd-find, fzf, jq, tmux, btop, ncdu, gh, neovim, pipx, zoxide, wslu, uv, and more). Run it instead of installing by hand; it skips anything already present.

### Node/npm global CLI path policy

This setup pins global npm CLI installs (including Codex) to:

- `NPM_CONFIG_PREFIX=$HOME/.npm-global`
- `PATH` prepends `$HOME/.npm-global/bin`

This prevents split-path issues where `npm -g` updates one Codex binary while shell resolves another.

Verify in a login shell:

```bash
command -v codex && codex --version && npm prefix -g
```

### GitHub CLI From WSL

`gh auth login` works best when `wslu` is installed, because that provides `wslview`.
Default workflow in this repo is **HTTPS** with GitHub CLI credentials; SSH is optional if you prefer key-based Git.

Verify:

```bash
command -v wslview
echo "$BROWSER"
```

Then log in:

```bash
gh auth login
```

Recommended answers:

- account: `GitHub.com`
- protocol: `HTTPS`
- authenticate git with GitHub credentials: `Yes`
- auth method: `Login with a web browser`

If the browser flow fails, go directly to [github.com/login/device](https://github.com/login/device) in Windows and enter the one-time code shown by `gh`.

### Prompt Notes

The prompt itself lives in `.p10k.zsh`.

This workstation uses the classic Powerlevel10k layout with:

- user and host on the left
- full working directory
- git branch/status
- command status, timing, and clock on the right

If you change the prompt, update both the live WSL file and the tracked copy here.

---

## Initial Setup

Ubuntu 24.04 LTS installed via `wsl --install -d Ubuntu` from PowerShell (done by `dotfiles/install.ps1`). Launch Ubuntu once to create your user, then re-run `install.ps1` — it runs `wsl/setup.sh`, which installs the apt packages, zsh + oh-my-zsh + Powerlevel10k, yt-dlp, uv, the shell files, and the claude/codex/grok/vibe CLIs. Shell is zsh with Powerlevel10k.

### Git identity

```bash
git config --global user.name "Rob Hedglen"
git config --global user.email "YOUR_GITHUB_EMAIL"
```

### SSH key for GitHub

```bash
ssh-keygen -t ed25519 -C "YOUR_GITHUB_EMAIL"
cat ~/.ssh/id_ed25519.pub
```

Copy the output, go to [github.com/settings/keys](https://github.com/settings/keys), click **New SSH key**, title it `WSL Ubuntu`, paste the key.

Test:

```bash
ssh -T git@github.com
```

---

## Key Paths

| What | Path |
|------|------|
| WSL home | `$HOME` |
| Windows home | `$WIN_HOME` |
| Workstation folder | `$WIN_HOME/workstation` |
| Dotfiles | `$WIN_HOME/workstation/dotfiles` |
| Music library | `/mnt/r/Media/Music` |
| Video download inbox | `/mnt/r/Media/x/dl` (same as Windows `R:\Media\x\dl`) |
| zsh config | `~/.zshrc` |

---

## Aliases

### dl (yt-dlp wrapper)

Downloads best quality video + audio to the Windows media folder. Uses Chrome cookies for YouTube authentication.

**Note:** Chrome encrypts cookies with Windows DPAPI, so WSL can't read them while Chrome is running. For YouTube downloads, use the PowerShell `dl` function instead. This alias works for non-YouTube sites that don't need cookies.

```bash
alias dl='yt-dlp -o "/mnt/r/Media/x/dl/%(title)s.%(ext)s"'
```

---

## PowerShell vs WSL — When to Use Which

| Task | Use |
|------|-----|
| YouTube downloads | PowerShell (cookies work) |
| winget / Windows apps | PowerShell |
| dotfiles management | PowerShell (source of truth is Windows side) |
| Claude Code | WSL |
| Bash scripts from the internet | WSL |
| Bulk file rename / find / process | WSL |
| ffmpeg batch jobs | Either (WSL is slightly easier to chain) |
| SSH into servers | WSL |
| Git push/pull | Either (default HTTPS via `gh`; SSH optional if keys are configured) |

---

## Troubleshooting

### pip not found

```bash
sudo apt install -y python3-pip
```

### Command installed but not found

Probably in `~/.local/bin`. Make sure PATH is set:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### zsh glob errors with %

Zsh interprets `%` as glob patterns. Wrap paths with `%(` in proper quotes or escape them.

### Permission denied on Windows files

Close the Windows app that has the file locked, or copy the file to `/tmp/` first.

### Reset WSL completely

From PowerShell:

```powershell
wsl --unregister Ubuntu
wsl --install -d Ubuntu
```

This wipes the Linux side. Windows files are untouched.
