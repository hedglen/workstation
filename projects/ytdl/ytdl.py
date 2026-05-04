#!/usr/bin/env python3
"""ytdl — yt-dlp wrapper. Downloads to the configured Videos folder."""

import os
import subprocess
import sys
import tomllib
from pathlib import Path

from rich.console import Console
from rich.panel import Panel

console = Console()

SCRIPT_DIR = Path(__file__).resolve().parent
CONFIG_PATH = SCRIPT_DIR / "config.toml"
IMPLICIT_COOKIES = SCRIPT_DIR / "cookies.txt"


def load_config() -> dict:
    with open(CONFIG_PATH, "rb") as f:
        return tomllib.load(f)


def resolve_cookie_file_path(raw: str) -> Path:
    p = Path(os.path.expandvars(raw.strip())).expanduser()
    if not p.is_absolute():
        p = SCRIPT_DIR / p
    return p


def resolve_download_dir(raw: str) -> Path:
    p = Path(os.path.expandvars(raw.strip())).expanduser()
    if not p.is_absolute():
        p = SCRIPT_DIR / p
    return p


def build_args(url: str, cfg: dict, quality: str | None, audio_only: bool) -> tuple[list[str], bool]:
    out_dir = resolve_download_dir(cfg["paths"]["download_dir"])
    fmt = cfg["defaults"]["format"]
    q = quality or cfg["defaults"]["quality"]

    ccfg = cfg.get("cookies") or {}
    cookie_file_raw = (ccfg.get("file") or "").strip()
    cookie_spec = (ccfg.get("from_browser") or "chrome:Default").strip()
    args = ["yt-dlp", "--no-mtime", "--no-playlist", "-o", str(out_dir / "%(title)s.%(ext)s")]
    used_browser_cookies = False

    cookie_path: Path | None = None
    if cookie_file_raw:
        cand = resolve_cookie_file_path(cookie_file_raw)
        if cand.is_file():
            cookie_path = cand
    elif IMPLICIT_COOKIES.is_file():
        cookie_path = IMPLICIT_COOKIES

    if cookie_path is not None:
        args[3:3] = ["--cookies", str(cookie_path)]
    elif cookie_spec:
        args[3:3] = ["--cookies-from-browser", cookie_spec]
        used_browser_cookies = True

    if not audio_only:
        args.insert(1, "--no-config")

    if audio_only:
        args += ["-x", "--audio-format", "mp3"]
        if cfg["defaults"]["embed_thumbnail"]:
            args += ["--embed-thumbnail"]
    else:
        if q == "best":
            args += ["-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"]
        elif q in ("1080", "720", "480"):
            args += ["-f", f"bestvideo[height<={q}][ext=mp4]+bestaudio[ext=m4a]/best[height<={q}]"]
        else:
            args += ["-f", "best"]

        args += ["--merge-output-format", fmt]

        if cfg["defaults"]["subtitles"]:
            args += ["--write-subs", "--embed-subs"]

    args.append(url)
    return args, used_browser_cookies


def drop_browser_cookies_args(cmd: list[str]) -> list[str]:
    cleaned: list[str] = []
    i = 0
    while i < len(cmd):
        if cmd[i] == "--cookies-from-browser":
            i += 2
            continue
        cleaned.append(cmd[i])
        i += 1
    return cleaned


def get_browser_cookie_spec(cmd: list[str]) -> str | None:
    for i, token in enumerate(cmd):
        if token == "--cookies-from-browser" and i + 1 < len(cmd):
            return cmd[i + 1]
    return None


def replace_browser_cookie_spec(cmd: list[str], new_spec: str) -> list[str]:
    updated = cmd.copy()
    for i, token in enumerate(updated):
        if token == "--cookies-from-browser" and i + 1 < len(updated):
            updated[i + 1] = new_spec
            break
    return updated


def main():
    cfg = load_config()
    download_dir = resolve_download_dir(cfg["paths"]["download_dir"])

    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        console.print(Panel(
            "[bold]ytdl[/bold] [cyan]<url>[/cyan] [dim][[--audio] [--quality 1080|720|480|best] [--playlist]][/dim]\n\n"
            "  [cyan]--audio[/cyan]       Download audio only (mp3)\n"
            "  [cyan]--quality[/cyan]     Video quality: best (default), 1080, 720, 480\n"
            "  [cyan]--playlist[/cyan]    Download full playlist (single video by default)\n\n"
            f"Downloads go to [yellow]{download_dir}[/yellow]",
            title="yt-dlp wrapper",
            border_style="blue"
        ))
        sys.exit(0)

    args = sys.argv[1:]
    audio_only = "--audio" in args
    playlist = "--playlist" in args
    args = [a for a in args if a != "--playlist"]
    quality = None

    if "--quality" in args:
        idx = args.index("--quality")
        quality = args[idx + 1]
        args = [a for i, a in enumerate(args) if i not in (idx, idx + 1)]

    url = next((a for a in args if a.startswith("http")), None)
    if not url:
        console.print("[red]Error:[/red] No URL provided.")
        sys.exit(1)

    cmd, used_browser_cookies = build_args(url, cfg, quality, audio_only)
    if playlist:
        cmd = [c for c in cmd if c != "--no-playlist"]

    mode = "audio (mp3)" if audio_only else f"video ({quality or cfg['defaults']['quality']})"
    console.print(f"[bold blue]↓[/bold blue] Downloading [cyan]{mode}[/cyan]")
    console.print(f"[dim]{url}[/dim]\n")

    result = subprocess.run(cmd)
    retried_without_browser_cookies = False
    retried_with_edge_cookies = False
    if result.returncode != 0 and used_browser_cookies:
        cookie_spec = (get_browser_cookie_spec(cmd) or "").lower()

        # Chrome on Windows often fails due to DB lock/DPAPI. Try Edge next if Chrome was requested.
        if cookie_spec.startswith("chrome:"):
            edge_cmd = replace_browser_cookie_spec(cmd, "edge:Default")
            if edge_cmd != cmd:
                retried_with_edge_cookies = True
                console.print(
                    "\n[yellow]![/yellow] Chrome browser-cookie auth failed.\n"
                    "[cyan]↻[/cyan] Retrying with [bold]edge:Default[/bold] cookies..."
                )
                result = subprocess.run(edge_cmd)
                cmd = edge_cmd

        if result.returncode != 0:
            retry_cmd = drop_browser_cookies_args(cmd)
            if retry_cmd != cmd:
                retried_without_browser_cookies = True
                console.print(
                    "\n[yellow]![/yellow] Browser-cookie auth still failing.\n"
                    "[cyan]↻[/cyan] Retrying without browser cookies for public-access download..."
                )
                result = subprocess.run(retry_cmd)

    if result.returncode == 0:
        if retried_with_edge_cookies:
            console.print("[green]Note:[/green] Download succeeded using Edge cookies fallback.")
        if retried_without_browser_cookies:
            console.print(
                "[yellow]Note:[/yellow] Download succeeded without browser cookies. "
                "For login-gated videos, export Netscape cookies.txt to use stable cookie auth."
            )
        console.print(f"\n[bold green]✓[/bold green] Saved to [yellow]{download_dir}[/yellow]")
    else:
        console.print("\n[bold red]✗[/bold red] Download failed.")
        if "xhamster.com" in url:
            console.print(
                "[yellow]XHamster is currently flaky with yt-dlp on some videos (known upstream extractor issue).[/yellow]\n"
                "[bold]If the video plays in browser but still fails:[/bold]\n"
                "  [cyan]1[/cyan]  Export Netscape [bold]cookies.txt[/bold] and save it as "
                f"[green]{IMPLICIT_COOKIES}[/green].\n"
                "  [cyan]2[/cyan]  Retry [bold]dl[/bold]. If it still fails, it is likely an active extractor break.\n"
                "  [cyan]3[/cyan]  Track status: [dim]https://github.com/yt-dlp/yt-dlp/issues/15497[/dim]"
            )
        if used_browser_cookies:
            console.print(
                "[yellow]Chrome’s cookie database is still locked after unlock was attempted.[/yellow] "
                "ChromeCookieUnlock often cannot force-release current Chrome builds.\n\n"
                "[bold]What works:[/bold]\n"
                f"  [cyan]1[/cyan]  Export Netscape [bold]cookies.txt[/bold] (e.g. “Get cookies.txt LOCALLY” extension), "
                f"save as [green]{IMPLICIT_COOKIES}[/green] — [dim]ytdl uses it automatically if present[/dim].\n"
                "  [cyan]2[/cyan]  Or end [bold]every[/bold] [dim]chrome.exe[/dim] in Task Manager (incl. background), then run [bold]dl[/bold] again.\n"
                "  [cyan]3[/cyan]  Or try [dim][cookies].from_browser = \"edge:Default\"[/dim] if you use Edge for that site.\n\n"
                "[dim]https://github.com/yt-dlp/yt-dlp/issues/7271[/dim]"
            )
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
