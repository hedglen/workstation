# yt-dlp plugins

Custom extractor plugins shipped with this dotfiles repo. Each subfolder follows yt-dlp's plugin layout:

```
plugins/<package>/yt_dlp_plugins/extractor/<name>.py
```

`install.ps1` symlinks each `<package>` folder into `%APPDATA%\yt-dlp\plugins\<package>`, where yt-dlp picks it up automatically (no `--use-extractors` flag needed).

## Plugins

| Package | Extractor | Sites |
|---------|-----------|-------|

## Adding a new plugin

1. Create `plugins/<package>/yt_dlp_plugins/extractor/<name>.py` exposing a class that subclasses `yt_dlp.extractor.common.InfoExtractor`.
2. Add a `@{ src = "projects\ytdl\plugins\<package>"; dst = "$env:APPDATA\yt-dlp\plugins\<package>"; ... }` entry to the symlink map in `dotfiles/install.ps1`.
3. Run `.\install.ps1 -ConfigsOnly` from the dotfiles directory to symlink it.
4. Verify with `yt-dlp --list-extractors | findstr /i <name>`.

Plugin docs: <https://github.com/yt-dlp/yt-dlp/wiki/Plugins>
