#!/usr/bin/env python3
"""Generate feed.xml from the published pieces listed on writing.html."""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import date, datetime, time, timezone, timedelta
from email.utils import format_datetime
from html.parser import HTMLParser
from pathlib import Path
from typing import Any
from urllib.parse import urljoin
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
SITE_URL = "https://hedglen.org/"
FEED_TITLE = "Rob Hedglen — Writing"
FEED_DESCRIPTION = "Creative nonfiction, essays, craft notes, and long-form work by Rob Hedglen."
FEED_PATH = ROOT / "feed.xml"
WRITING_PATH = ROOT / "writing.html"
SITE_TZ = timezone(timedelta(hours=-4))


@dataclass
class WritingCard:
    href: str
    title: str
    category: str
    summary: str


@dataclass
class FeedItem:
    title: str
    url: str
    guid: str
    published: date
    modified: date
    category: str
    description: str


class WritingPageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.cards: list[WritingCard] = []
        self._card_depth = 0
        self._in_card = False
        self._in_meta = False
        self._in_h2 = False
        self._in_p = False
        self._href = ""
        self._title: list[str] = []
        self._meta: list[str] = []
        self._summary: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr = dict(attrs)
        classes = set((attr.get("class") or "").split())

        if tag == "div" and "writing-card" in classes and not self._in_card:
            self._in_card = True
            self._card_depth = 1
            self._href = ""
            self._title = []
            self._meta = []
            self._summary = []
            return

        if not self._in_card:
            return

        if tag == "div":
            self._card_depth += 1
        elif tag == "span" and "meta" in classes:
            self._in_meta = True
        elif tag == "h2":
            self._in_h2 = True
        elif tag == "a" and self._in_h2 and not self._href:
            self._href = attr.get("href") or ""
        elif tag == "p":
            self._in_p = True

    def handle_endtag(self, tag: str) -> None:
        if not self._in_card:
            return

        if tag == "span" and self._in_meta:
            self._in_meta = False
        elif tag == "h2":
            self._in_h2 = False
        elif tag == "p":
            self._in_p = False
        elif tag == "div":
            self._card_depth -= 1
            if self._card_depth == 0:
                self._finish_card()

    def handle_data(self, data: str) -> None:
        if not self._in_card:
            return

        if self._in_meta:
            self._meta.append(data)
        elif self._in_h2:
            self._title.append(data)
        elif self._in_p:
            self._summary.append(data)

    def _finish_card(self) -> None:
        meta = clean_text(" ".join(self._meta))
        category = clean_text(meta.split("·", 1)[0])
        card = WritingCard(
            href=self._href.strip(),
            title=clean_text(" ".join(self._title)),
            category=category,
            summary=clean_text(" ".join(self._summary)),
        )
        if card.href and card.title:
            self.cards.append(card)

        self._in_card = False


class JsonLdParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.blocks: list[str] = []
        self._in_jsonld = False
        self._current: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attr = dict(attrs)
        if tag == "script" and attr.get("type") == "application/ld+json":
            self._in_jsonld = True
            self._current = []

    def handle_endtag(self, tag: str) -> None:
        if tag == "script" and self._in_jsonld:
            self.blocks.append("".join(self._current))
            self._in_jsonld = False

    def handle_data(self, data: str) -> None:
        if self._in_jsonld:
            self._current.append(data)


def clean_text(value: str) -> str:
    return " ".join(value.split())


def parse_date(value: str | None) -> date:
    if not value:
        raise ValueError("Missing required article date")
    return datetime.fromisoformat(value[:10]).date()


def as_rfc2822(value: date) -> str:
    dt = datetime.combine(value, time(0, 0), SITE_TZ)
    return format_datetime(dt)


def article_from_jsonld(path: Path) -> dict[str, Any]:
    parser = JsonLdParser()
    parser.feed(path.read_text(encoding="utf-8"))

    for block in parser.blocks:
        data = json.loads(block)
        candidates = []
        if isinstance(data, dict) and "@graph" in data:
            candidates.extend(data["@graph"])
        else:
            candidates.append(data)

        for candidate in candidates:
            if candidate.get("@type") == "Article":
                return candidate

    raise ValueError(f"No Article JSON-LD found in {path.relative_to(ROOT)}")


def writing_cards() -> list[WritingCard]:
    parser = WritingPageParser()
    parser.feed(WRITING_PATH.read_text(encoding="utf-8"))
    return parser.cards


def feed_items() -> list[FeedItem]:
    items: list[FeedItem] = []

    for card in writing_cards():
        article_path = ROOT / card.href
        article = article_from_jsonld(article_path)
        published = parse_date(article.get("datePublished"))
        modified = parse_date(article.get("dateModified") or article.get("datePublished"))
        url = article.get("url") or urljoin(SITE_URL, card.href)
        title = article.get("headline") or card.title
        description = article.get("description") or card.summary
        category = article.get("genre") or card.category

        items.append(
            FeedItem(
                title=clean_text(title),
                url=url,
                guid=url,
                published=published,
                modified=modified,
                category=clean_text(category).title(),
                description=clean_text(description),
            )
        )

    return sorted(items, key=lambda item: (item.published, item.title), reverse=True)


def build_feed(items: list[FeedItem]) -> ET.ElementTree:
    ET.register_namespace("atom", "http://www.w3.org/2005/Atom")
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")

    ET.SubElement(channel, "title").text = FEED_TITLE
    ET.SubElement(channel, "link").text = urljoin(SITE_URL, "writing.html")
    ET.SubElement(
        channel,
        "{http://www.w3.org/2005/Atom}link",
        {"href": urljoin(SITE_URL, "feed.xml"), "rel": "self", "type": "application/rss+xml"},
    )
    ET.SubElement(channel, "description").text = FEED_DESCRIPTION
    ET.SubElement(channel, "language").text = "en-us"
    last_build = max((item.modified for item in items), default=date.today())
    ET.SubElement(channel, "lastBuildDate").text = as_rfc2822(last_build)

    image = ET.SubElement(channel, "image")
    ET.SubElement(image, "url").text = urljoin(SITE_URL, "favicon-96x96.png")
    ET.SubElement(image, "title").text = FEED_TITLE
    ET.SubElement(image, "link").text = urljoin(SITE_URL, "writing.html")
    ET.SubElement(image, "width").text = "96"
    ET.SubElement(image, "height").text = "96"

    for feed_item in items:
        item = ET.SubElement(channel, "item")
        ET.SubElement(item, "title").text = feed_item.title
        ET.SubElement(item, "link").text = feed_item.url
        ET.SubElement(item, "guid", {"isPermaLink": "true"}).text = feed_item.guid
        ET.SubElement(item, "pubDate").text = as_rfc2822(feed_item.published)
        ET.SubElement(item, "category").text = feed_item.category
        ET.SubElement(item, "description").text = feed_item.description

    ET.indent(rss, space="  ")
    return ET.ElementTree(rss)


def main() -> None:
    tree = build_feed(feed_items())
    tree.write(FEED_PATH, encoding="utf-8", xml_declaration=True)
    FEED_PATH.write_text(FEED_PATH.read_text(encoding="utf-8") + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
