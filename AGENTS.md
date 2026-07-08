# AGENTS.md

## Cursor Cloud specific instructions

This repo is a **Windows 11 workstation configuration ("dotfiles") monorepo**, not a deployable
service. There is no backend/database/web API to orchestrate. General project layout and
conventions live in `CLAUDE.md` and `README.md`.

### What can (and cannot) run on the Linux cloud VM
- The core product, `install.ps1` (+ `lib/*.ps1`, `maintenance/update.ps1`), is **Windows-only**
  (winget/Scoop/registry/`%USERPROFILE%` symlinks) and **PowerShell is not installed** here. It
  cannot be exercised end-to-end on this Linux VM.
- The cross-platform pieces that DO run here:
  - **Static site** `hedglen.github.io/` — plain static HTML/CSS/vanilla JS.
  - **Python CLIs** `projects/ytdl/` and `projects/media-organizer/`.

### Static site (`hedglen.github.io/`)
- Serve locally: `python3 -m http.server 8000` from inside `hedglen.github.io/`, then open
  `http://localhost:8000/`. No build step or dependencies.
- Regenerate the RSS feed: `python3 scripts/generate_feed.py` (Python **stdlib only**, no venv
  needed). It parses `writing.html` + article JSON-LD and rewrites `feed.xml` deterministically.
  In CI this runs via `.github/workflows/update-feed.yml` on push to `main`.

### Python CLIs (`projects/ytdl`, `projects/media-organizer`)
- Each project uses its own venv at `projects/<name>/.venv` (gitignored). The update script
  creates them and installs each `requirements.txt`. Run tools via the venv interpreter, e.g.
  `projects/media-organizer/.venv/bin/python organize.py --dir <folder>`.
- `config.toml` in both projects hardcodes **Windows paths** (e.g. `R:/Media/...`). To test on
  Linux, pass an explicit folder: `organize.py --dir /tmp/inbox` (defaults to a dry run; add
  `--apply` to move files).
- `ytdl` shells out to an external `yt-dlp` binary (installed via winget on Windows, not bundled);
  `ytdl.py --help` works without it, but actual downloads require `yt-dlp` + FFmpeg on PATH.

### Gotchas
- Creating venvs requires the system package `python3.12-venv` (already provisioned in the VM
  snapshot); `python3 -m venv` fails with an `ensurepip` error without it.
- There is **no automated test suite and no linter config** in this repo. The closest thing to a
  test harness is `scripts/workstation-health.ps1` (PowerShell, Windows-oriented).
