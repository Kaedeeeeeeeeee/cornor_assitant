#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
LANDING_DIR = ROOT / "CornerAssistantApp" / "landing-page"
INDEX_PATH = LANDING_DIR / "index.html"
MAIN_JS_PATH = LANDING_DIR / "main.js"


HTML_REPLACEMENTS = {
    '<a class="store-button is-disabled" href="#" aria-disabled="true" data-analytics-event="app_store_cta">':
        '<a class="store-button" href="{url}" target="_blank" rel="noopener" data-analytics-event="app_store_cta">',
    '<a class="store-button is-disabled" href="#" aria-disabled="true" data-analytics-event="app_store_cta_bottom">':
        '<a class="store-button" href="{url}" target="_blank" rel="noopener" data-analytics-event="app_store_cta_bottom">',
    '<small data-i18n="ctaTop">即将登陆</small>':
        '<small data-i18n="ctaTop">前往</small>',
    '<p data-i18n="finalSub">安静地待命，需要时一推即到。即将登陆 Mac App Store。</p>':
        '<p data-i18n="finalSub">安静地待命，需要时一推即到。现在可在 Mac App Store 下载。</p>',
}

MAIN_JS_REPLACEMENTS = {
    'ctaTop: "即将登陆",': 'ctaTop: "前往",',
    'finalSub: "安静地待命，需要时一推即到。即将登陆 Mac App Store。",':
        'finalSub: "安静地待命，需要时一推即到。现在可在 Mac App Store 下载。",',
    'ctaTop: "Coming soon to",': 'ctaTop: "Download on the",',
    'finalSub: "Quiet until needed, one push away. Coming soon to the Mac App Store.",':
        'finalSub: "Quiet until needed, one push away. Now available on the Mac App Store.",',
    'ctaTop: "近日公開",': 'ctaTop: "ダウンロード",',
    'finalSub: "必要な時だけ、画面端からすぐに。Mac App Store で近日公開予定です。",':
        'finalSub: "必要な時だけ、画面端からすぐに。Mac App Store で配信中です。",',
}


def validate_app_store_url(value: str) -> str:
    url = value.strip()
    if not url:
        raise ValueError("App Store URL is empty")

    parsed = urlparse(url)
    if parsed.scheme != "https":
        raise ValueError("App Store URL must use https")
    if parsed.netloc.lower() != "apps.apple.com":
        raise ValueError("App Store URL host must be apps.apple.com")
    if "/app/" not in parsed.path:
        raise ValueError("App Store URL path must contain /app/")
    if not re.search(r"/id\d{6,}(?:$|[/?#])", parsed.path):
        raise ValueError("App Store URL path must contain an App Store id segment such as /id1234567890")
    return url


def replace_expected(text: str, replacements: dict[str, str]) -> tuple[str, list[str]]:
    changed: list[str] = []
    for old, new in replacements.items():
        if old in text:
            text = text.replace(old, new)
            changed.append(old)
        elif new not in text:
            raise ValueError(f"Could not find expected source or target text: {old}")
    return text, changed


def update_index_html(url: str) -> tuple[str, list[str]]:
    text = INDEX_PATH.read_text(encoding="utf-8")
    html_replacements = {old: new.format(url=url) for old, new in HTML_REPLACEMENTS.items()}
    text, changed = replace_expected(text, html_replacements)

    url_json = json.dumps(url, ensure_ascii=False)
    if '"installUrl"' not in text:
        old = '      "url": "https://kaedeeeeeeeeee.github.io/cornor_assitant/",\n'
        new = old + f'      "installUrl": {url_json},\n'
        if old not in text:
            raise ValueError("Could not find JSON-LD application url field")
        text = text.replace(old, new, 1)
        changed.append("jsonld.installUrl")

    if '"priceCurrency": "USD"\n      }' in text:
        old = '        "priceCurrency": "USD"\n      }'
        new = f'        "priceCurrency": "USD",\n        "url": {url_json}\n      }}'
        text = text.replace(old, new, 1)
        changed.append("jsonld.offers.url")
    elif f'"url": {url_json}' not in text:
        raise ValueError("Could not find JSON-LD offers block to update")

    return text, changed


def update_main_js() -> tuple[str, list[str]]:
    text = MAIN_JS_PATH.read_text(encoding="utf-8")
    return replace_expected(text, MAIN_JS_REPLACEMENTS)


def run_validator() -> None:
    result = subprocess.run(
        [str(ROOT / "script" / "validate_landing_local.js")],
        cwd=ROOT,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Activate Peek landing page App Store CTAs after the real Mac App Store URL is available."
    )
    parser.add_argument("--url", default=os.environ.get("PEEK_APP_STORE_URL", ""), help="Real Mac App Store URL")
    parser.add_argument("--dry-run", action="store_true", help="Validate and print planned changes without writing files")
    parser.add_argument("--skip-validate", action="store_true", help="Skip local landing validation after writing")
    args = parser.parse_args()

    try:
        url = validate_app_store_url(args.url)
        index_html, html_changes = update_index_html(url)
        main_js, js_changes = update_main_js()
    except ValueError as exc:
        print(f"configure_app_store_url failed: {exc}", file=sys.stderr)
        return 1

    print(f"App Store URL accepted: {url}")
    print(f"index.html changes: {len(html_changes)}")
    print(f"main.js changes: {len(js_changes)}")

    if args.dry_run:
        print("DRY RUN: no files written")
        return 0

    INDEX_PATH.write_text(index_html, encoding="utf-8")
    MAIN_JS_PATH.write_text(main_js, encoding="utf-8")
    print(f"Updated {INDEX_PATH}")
    print(f"Updated {MAIN_JS_PATH}")

    if not args.skip_validate:
        run_validator()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
