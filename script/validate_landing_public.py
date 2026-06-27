#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import struct
import sys
import urllib.request
import xml.etree.ElementTree as ET
from html.parser import HTMLParser


BASE_URL = "https://kaedeeeeeeeeee.github.io/cornor_assitant/"
EXPECTED_URLS = {
    BASE_URL,
    f"{BASE_URL}privacy.html",
    f"{BASE_URL}support.html",
}
SEARCH_BOT_USER_AGENTS = {
    "googlebot": "Googlebot/2.1 (+http://www.google.com/bot.html)",
    "bingbot": "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)",
}
FORBIDDEN_PUBLIC_COPY = [
    "Bing",
    "selected text",
    "Selected text",
    "选中文字",
    "macOS 14",
    "Sonoma",
]


class LandingHTMLParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.title = ""
        self._in_title = False
        self._in_ld_json = False
        self._ld_buffer: list[str] = []
        self.meta: dict[str, str] = {}
        self.links: dict[str, str] = {}
        self.ld_json: list[str] = []
        self.text: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_dict = {key.lower(): value or "" for key, value in attrs}
        tag = tag.lower()

        if tag == "title":
            self._in_title = True
        elif tag == "meta":
            key = attrs_dict.get("name") or attrs_dict.get("property")
            if key:
                self.meta[key] = attrs_dict.get("content", "")
        elif tag == "link":
            rel = attrs_dict.get("rel")
            href = attrs_dict.get("href")
            if rel and href:
                self.links[rel] = href
        elif tag == "script" and attrs_dict.get("type") == "application/ld+json":
            self._in_ld_json = True
            self._ld_buffer = []

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag == "title":
            self._in_title = False
        elif tag == "script" and self._in_ld_json:
            self._in_ld_json = False
            self.ld_json.append("".join(self._ld_buffer).strip())

    def handle_data(self, data: str) -> None:
        if self._in_title:
            self.title += data
        elif self._in_ld_json:
            self._ld_buffer.append(data)
        else:
            self.text.append(data)


def fetch_text(url: str, user_agent: str = "PeekLaunchVerifier/1.0") -> str:
    request = urllib.request.Request(url, headers={"User-Agent": user_agent})
    with urllib.request.urlopen(request, timeout=20) as response:
        status = getattr(response, "status", 200)
        if status != 200:
            raise ValueError(f"{url} returned HTTP {status}")
        return response.read().decode("utf-8")


def fetch_bytes(url: str) -> bytes:
    request = urllib.request.Request(url, headers={"User-Agent": "PeekLaunchVerifier/1.0"})
    with urllib.request.urlopen(request, timeout=20) as response:
        status = getattr(response, "status", 200)
        if status != 200:
            raise ValueError(f"{url} returned HTTP {status}")
        return response.read()


def png_size(data: bytes, label: str) -> tuple[int, int]:
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise ValueError(f"{label} is not a PNG image")
    return struct.unpack(">II", data[16:24])


def validate_homepage(errors: list[str]) -> None:
    html = fetch_text(BASE_URL)
    parser = LandingHTMLParser()
    parser.feed(html)

    print(f"landing.title: {parser.title.strip()}")
    print(f"landing.canonical: {parser.links.get('canonical')}")
    print(f"landing.description: {parser.meta.get('description')}")
    print(f"landing.twitter_card: {parser.meta.get('twitter:card')}")

    if parser.links.get("canonical") != BASE_URL:
        errors.append("homepage canonical URL does not match production URL")
    if not parser.meta.get("description"):
        errors.append("homepage meta description is missing")
    if not parser.meta.get("og:title"):
        errors.append("homepage og:title is missing")
    if parser.meta.get("twitter:card") != "summary_large_image":
        errors.append("homepage Twitter card is not summary_large_image")

    html_forbidden_scan = html.casefold()
    for forbidden in FORBIDDEN_PUBLIC_COPY:
        if forbidden.casefold() in html_forbidden_scan:
            errors.append(f"homepage contains forbidden public copy: {forbidden}")

    parsed_ld = []
    for raw_json in parser.ld_json:
        try:
            parsed_ld.append(json.loads(raw_json))
        except json.JSONDecodeError as exc:
            errors.append(f"homepage JSON-LD does not parse: {exc}")

    software_apps = [item for item in parsed_ld if item.get("@type") == "SoftwareApplication"]
    if not software_apps:
        errors.append("homepage SoftwareApplication JSON-LD is missing")
    else:
        app = software_apps[0]
        print(f"landing.jsonld.applicationCategory: {app.get('applicationCategory')}")
        if app.get("name") != "Peek":
            errors.append("homepage JSON-LD name is not Peek")
        if app.get("applicationCategory") != "Productivity":
            errors.append("homepage JSON-LD applicationCategory is not Productivity")
        if app.get("operatingSystem") != "macOS 15.0 or later":
            errors.append("homepage JSON-LD operatingSystem does not match macOS 15.0+")


def sitemap_locations(xml_body: str) -> set[str]:
    root = ET.fromstring(xml_body)
    namespace = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    return {loc.text for loc in root.findall(".//sm:loc", namespace) if loc.text}


def validate_sitemap_locations(label: str, sitemap_body: str, errors: list[str]) -> None:
    locations = sitemap_locations(sitemap_body)
    print(f"landing.sitemap.{label}.urls: {len(locations)}")
    missing = EXPECTED_URLS - locations
    if missing:
        errors.append(f"sitemap missing URLs for {label}: {', '.join(sorted(missing))}")


def validate_robots_and_sitemap(errors: list[str]) -> None:
    robots = fetch_text(f"{BASE_URL}robots.txt")
    sitemap_url = f"{BASE_URL}sitemap.xml"
    print(f"landing.robots_has_sitemap: {sitemap_url in robots}")
    if sitemap_url not in robots:
        errors.append("robots.txt does not declare the production sitemap")

    sitemap = fetch_text(sitemap_url)
    validate_sitemap_locations("default", sitemap, errors)

    for bot_name, user_agent in SEARCH_BOT_USER_AGENTS.items():
        bot_sitemap = fetch_text(sitemap_url, user_agent=user_agent)
        validate_sitemap_locations(bot_name, bot_sitemap, errors)


def validate_manifest_and_analytics(errors: list[str]) -> None:
    manifest = json.loads(fetch_text(f"{BASE_URL}site.webmanifest"))
    print(f"landing.manifest.name: {manifest.get('name')}")
    if manifest.get("name") != "Peek":
        errors.append("site.webmanifest name is not Peek")

    manifest_icons = manifest.get("icons")
    if not isinstance(manifest_icons, list):
        errors.append("site.webmanifest icons is not a list")
    else:
        matching_icons = [
            icon for icon in manifest_icons
            if isinstance(icon, dict) and icon.get("src") == "assets/icon.png"
        ]
        if not matching_icons:
            errors.append("site.webmanifest does not reference assets/icon.png")
        else:
            sizes = {
                size
                for icon in matching_icons
                for size in str(icon.get("sizes", "")).split()
            }
            print(f"landing.manifest.icon_sizes: {sorted(sizes)}")
            if "1024x1024" not in sizes:
                errors.append("site.webmanifest assets/icon.png entry does not declare 1024x1024")

    icon_size = png_size(fetch_bytes(f"{BASE_URL}assets/icon.png"), "assets/icon.png")
    social_preview_size = png_size(fetch_bytes(f"{BASE_URL}assets/social-preview.png"), "assets/social-preview.png")
    print(f"landing.icon.size: {icon_size[0]}x{icon_size[1]}")
    print(f"landing.social_preview.size: {social_preview_size[0]}x{social_preview_size[1]}")
    if icon_size != (1024, 1024):
        errors.append(f"assets/icon.png expected 1024x1024, got {icon_size[0]}x{icon_size[1]}")
    if social_preview_size != (1200, 630):
        errors.append(f"assets/social-preview.png expected 1200x630, got {social_preview_size[0]}x{social_preview_size[1]}")

    analytics_config = fetch_text(f"{BASE_URL}analytics-config.js").strip()
    print(f"landing.analytics_config: {analytics_config}")
    match = re.fullmatch(r'window\.PEEK_GA_MEASUREMENT_ID = "([^"]*)";', analytics_config)
    if not match:
        errors.append("analytics-config.js has an unexpected format")
        return

    measurement_id = match.group(1)
    if measurement_id and not re.fullmatch(r"G-[A-Z0-9]+", measurement_id):
        errors.append("PEEK_GA_MEASUREMENT_ID is not empty and is not a GA4 G-* id")


def main() -> int:
    errors: list[str] = []
    try:
        validate_homepage(errors)
        validate_robots_and_sitemap(errors)
        validate_manifest_and_analytics(errors)
    except Exception as exc:  # noqa: BLE001 - this is a CLI verifier.
        errors.append(str(exc))

    if errors:
        print("\nLanding public validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nLanding public validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
