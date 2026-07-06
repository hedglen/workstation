# media-organizer

Batch rename and move video files from a Downloads inbox into a structured media library.

## Workflow

1. Move videos you want organized into `R:\Media\x\dl`
2. Run `orgmed` to preview, `orgmed --apply` to commit
3. Or run `orgmedx` to move everything straight to `x` and apply immediately

## Commands

| Command | What it does |
|---|---|
| `orgmed` | Preview rename + move for all files in the inbox (`R:\Media\x\dl` by default) |
| `orgmed --apply` | Apply rename + move (auto-classifies destination) |
| `orgmedx` | Rename + move everything to `x`, no prompts |
| `orgmed --apply --dest movies` | Force all files to Movies |
| `orgmed --apply --dest tv` | Force all files to TV Shows |
| `orgmed --apply --dest x` | Force all files to x |

## Library structure

**Inbox** (default folder `orgmed` scans — `paths.inbox` in `config.toml`):

```text
R:\Media\x\dl\
```

**Library roots** (where files move after rename — `paths` in `config.toml`):

```text
R:\Media\
├── Movies\             # Title (Year)\Title (Year).mkv
│   └── Elysium (2013)\
├── TV Shows\           # Show\Season XX\
│   └── Breaking Bad\
│       └── Season 01\
├── Music Videos\
└── x\                  # classified bucket; inbox is x\dl\ (sibling of loose files in x\)
    └── dl\             # organizer inbox (paths.inbox)
```

## Classification logic

- Filename starts with `PMV`, `SFM`, `MMD` → `x`
- guessit detects movie → `Movies/`
- guessit detects episode → `TV Shows/`
- Everything else → `x`

Add more prefixes/keywords that route to `x` in `config.toml` under `[x_patterns]` — no code changes needed.

## Setup (fresh machine)

```powershell
cd $HOME\projects\media-organizer
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
```

The `orgmed` and `orgmedx` aliases are defined in the [workstation PowerShell profile](https://github.com/hedglen/workstation).
