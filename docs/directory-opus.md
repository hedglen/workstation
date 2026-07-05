# Directory Opus setup guide

Directory Opus (dopus) is a full Explorer replacement for Windows with dual-pane browsing,
tabs, scripting, and deep customization. This guide covers the setup used on this machine.

---

## Already configured

- Single-click to open files and folders

---

## Core layout

### Dual pane

The primary reason to use Opus. Press `F3` or click the dual-pane button in the toolbar.

To make it the default for every new window:
`Settings → Preferences → Layouts & Styles → Default Lister → Set as Default Lister`

### Folder tabs

Keep multiple locations open in each pane — like browser tabs.

- `Ctrl+T` — new tab
- `Ctrl+W` — close tab
- Middle-click a tab to close it
- Drag folders onto the tab bar to open them as tabs

---

## Display settings

### Details view (recommended default)

`Settings → Preferences → Folders → Folder Formats`

- Set "Default Format" to **Details**
- Columns to enable: **Name, Size, Type, Date Modified, Attributes**
- Disable "Auto-size all columns" (slow on large folders — use `Numpad *` manually when needed)

### Preview pane

`F7` toggles it. Shows previews for images, text files, PDFs, and more.

Useful viewer plugins are available via `Help → Directory Opus Resource Centre`.

### Status bar

Shows item count, selection size, total folder size. Customize via:
`Settings → Preferences → Display → Status Bar`

### Full-row selection

`Settings → Preferences → File Display → Full-row selection` — **On**

Much easier to click rows accurately.

### Folders before files

`Settings → Preferences → Filtering and Sorting → Mix files and folders` — **Off**

Keeps folders grouped at the top.

---

## File operations

`Settings → Preferences → File Operations → Copying Files`

| Setting | Value |
|---|---|
| Show progress dialog | Always |
| Automatically manage copy queues | On |
| Confirm before deleting | On |

---

## Toolbar customizations

Right-click any toolbar → **Customize** to add/remove/reorder buttons.

### Open Windows Terminal here

Add a custom button with this command to open Windows Terminal in the current folder:

```
wt -d {sourcepath}
```

### Copy full path to clipboard

Built-in: **Edit → Copy Full Pathnames**, or add as a toolbar button:

```
Clipboard COPYNAMES=fullpath
```

---

## Explorer replacement

`Settings → Preferences → Launching Opus → Explorer Replacement`

Options:
- **Don't replace** — Opus only opens when launched manually
- **Replace for all file system folders** — full replacement (recommended)
- **Replace for all except Desktop** — good middle ground

---

## Keyboard shortcuts

| Key | Action |
|---|---|
| `F3` | Toggle dual pane |
| `F7` | Toggle viewer/preview pane |
| `F8` | Toggle folder tree |
| `F4` | Edit current path in location bar |
| `Tab` | Switch active pane (dual-pane mode) |
| `Ctrl+T` | New tab |
| `Ctrl+W` | Close tab |
| `Backspace` | Go up one level |
| `\` | Go to root of current drive |
| `Numpad *` | Auto-size columns |
| `F2` | Rename selected file |
| `Ctrl+A` | Select all |
| `Ctrl+I` | Invert selection |

---

## Folder colors

Color-code specific folders for quick visual recognition.

`Settings → Preferences → Folders → Folder Colors`

Useful for marking: projects root, downloads, active work directories.

---

## Dark theme

`Settings → Preferences → Display → Colors and Fonts`

Built-in dark themes are available, or download community themes from:
`Help → Directory Opus Resource Centre → Themes`

---

## Useful preferences summary

| Path | Setting | Value |
|---|---|---|
| File Display | Full-row selection | On |
| Filtering & Sorting | Mix files and folders | Off |
| Folders → Folder Behavior | Re-use existing Lister | On |
| File Operations → Copy | Auto-manage copy queues | On |
| Launching Opus | Explorer replacement | Replace all file system folders |

---

## Resource centre

`Help → Directory Opus Resource Centre` — official source for:

- Themes
- Viewer plugins (e.g. extended media preview support)
- Scripts and buttons
- Community configs

---

## Related

- [workstation-setup.md](./workstation-setup.md) — rebuild / verification
