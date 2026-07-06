# ytdl

yt-dlp wrapper with presets. Downloads go to the current user's `Videos` folder by default (see `config.toml`).

## Usage

```powershell
ytdl <url>                        # best quality video (mp4)
ytdl <url> --quality 1080         # cap at 1080p
ytdl <url> --audio                # audio only (mp3)
dl <url>                          # alias for ytdl
dll                               # list all supported extractors
```

## Config

- **`config.toml`** — wrapper: download directory, quality, format, **`[cookies].from_browser`**, etc.
- **`appdata-config`** — global **`yt-dlp` CLI** defaults (any bare `yt-dlp` invocation). **`install.ps1`** symlinks it to **`%APPDATA%\yt-dlp\config`**.
- **`plugins/`** — custom yt-dlp extractor plugins. **`install.ps1`** symlinks each package to **`%APPDATA%\yt-dlp\plugins\<package>`**. See `plugins/README.md`.

Cookies come from your real browser so logged-in / restricted videos work. Default is **`chrome:Default`**.

**Windows + Chrome:** yt-dlp must **copy** Chrome’s SQLite cookie file. While Chrome is running, that copy often fails. The **ChromeCookieUnlock** plugin (`install-chrome-cookie-plugin.ps1`) tries to release the lock via Restart Manager; on many current Chrome builds it still prints `Attempting to unlock cookies` and then **fails anyway**.

**What actually works:**

1. **Netscape `cookies.txt` next to `ytdl.py`** — save as `projects/ytdl/cookies.txt` (gitignored). The wrapper picks it up automatically; no config edit needed. Export from Chrome with an extension such as [Get cookies.txt LOCALLY](https://chromewebstore.google.com/detail/cclelndahbckbenkjhflpdbgdldlbecc) while logged into the site.

2. **`[cookies].file`** in `config.toml` — same format; path can be relative to the `ytdl` folder.

3. **Quit every `chrome.exe`** in Task Manager (including background), then run `dl` immediately.

4. **`from_browser = "edge:Default"`** if you use Edge for that site and it is not locking the same way.

Optional plugin install (best-effort): `.\install-chrome-cookie-plugin.ps1`. Background Chrome: disable **Settings → System → Continue running background apps when Google Chrome is closed**.

Details: [yt-dlp#7271](https://github.com/yt-dlp/yt-dlp/issues/7271), [ChromeCookieUnlock](https://github.com/seproDev/yt-dlp-ChromeCookieUnlock).

## Setup

```powershell
cd projects/ytdl
python -m venv .venv
.venv/Scripts/pip install rich
```

The `ytdl` alias is registered in the PowerShell profile (workstation repo).

## Supported Sites

### Video / Streaming

| Site | Extractor | Notes |
|------|-----------|-------|
| YouTube | `youtube`, `youtube:playlist`, `youtube:tab`, `youtube:clip` | Videos, playlists, Shorts, clips |
| Twitch | `twitch:vod`, `twitch:clips`, `twitch:collection` | VODs, highlight clips, collections |
| Vimeo | `vimeo`, `vimeo:album`, `vimeo:channel` | Indie/pro video hosting |
| Reddit | `reddit` | Video posts download cleanly |
| Twitter/X | `twitter`, `twitter:spaces` | Tweets with video, Spaces recordings |
| Bluesky | `Bluesky` | Video posts |
| Instagram | `instagram`, `instagram:story` | Reels, posts, stories |
| TikTok | `TikTok`, `tiktok:user` | Videos, user feeds |
| Kick | `kick:vod`, `kick:clips` | Streaming platform VODs and clips |
| Rumble | `Rumble`, `RumbleChannel` | Videos and channel feeds |

### Music

| Site | Extractor | Notes |
|------|-----------|-------|
| SoundCloud | `soundcloud`, `soundcloud:playlist`, `soundcloud:user` | Tracks, playlists, full profiles |
| Bandcamp | `Bandcamp`, `Bandcamp:album`, `Bandcamp:user` | Albums, tracks, artist pages |
| Audiomack | `audiomack`, `audiomack:album` | Hip-hop/R&B focused, free streaming |
| Last.fm | `LastFM`, `LastFMPlaylist` | Links out to actual audio tracks |
| Audius | `Audius`, `audius:playlist`, `audius:track` | Decentralized music platform |
| Mixcloud | `mixcloud`, `mixcloud:playlist` | DJ sets, mixes, radio shows |

### Tech / Learning

| Site | Extractor | Notes |
|------|-----------|-------|
| Udemy | `udemy`, `udemy:course` | Paid course videos (requires login) |
| Pluralsight | `pluralsight`, `pluralsight:course` | Dev/IT training |
| Frontend Masters | `FrontendMasters`, `FrontendMastersCourse` | Frontend-focused courses |
| Khan Academy | `khanacademy`, `khanacademy:unit` | Free educational content |
| Nebula | `nebula:video`, `nebula:channel`, `nebula:season` | Creator-owned streaming platform |
| LinkedIn Learning | `linkedin:learning`, `linkedin:learning:course` | Professional dev courses |

### Gaming / Clips

| Site | Extractor | Notes |
|------|-----------|-------|
| Xbox Clips | `XboxClips` | Clips from Xbox network |
| Steam | `SteamCommunity` | Community video posts |
| Medal.tv | `MedalTV` | Gaming clip highlights |

### Podcasts / Long-form Audio

| Site | Extractor | Notes |
|------|-----------|-------|
| Apple Podcasts | `ApplePodcasts` | Public episodes |
| Libsyn | `Libsyn` | Common podcast host |
| Simplecast | `simplecast`, `simplecast:episode` | Another common podcast host |
| Spreaker | `Spreaker`, `SpreakerShow` | Podcast platform |

### Utility / File Sharing

| Site | Extractor | Notes |
|------|-----------|-------|
| Dropbox | `Dropbox` | Shared video file links |
| Google Drive | `GoogleDrive`, `GoogleDrive:Folder` | Shared video links |
| Loom | `loom` | Screen recordings |
| Streamable | `Streamable` | Short video clip hosting |

## Supported Sites — Adult

Top working extractors (as of `dll` check):

| Site | Extractor |
|------|-----------|
| PornHub | `PornHub`, `PornHubPlaylist`, `PornHubUser` |
| XVideos | `XVideos`, `xvideos:quickies` |
| XHamster | `XHamster`, `XHamsterUser` |
| RedTube | `RedTube` |
| YouPorn | `YouPorn`, `YouPornCategory`, `YouPornChannel`, `YouPornCollection` |
| SpankBang | `SpankBang`, `SpankBangPlaylist` |
| Eporner | `Eporner` |
| TNAFlix | `TNAFlix` |
| RedGifs | `RedGifs`, `RedGifsSearch`, `RedGifsUser` |
| Motherless | `Motherless`, `MotherlessGallery`, `MotherlessGroup` |
