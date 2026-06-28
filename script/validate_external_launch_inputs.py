#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INPUTS_PATH = ROOT / "CornerAssistantApp" / "docs" / "External-Launch-Inputs.md"

REQUIRED_MARKERS = [
    "# Corner Peek External Launch Inputs",
    "## Analytics",
    "## Search Consoles",
    "## Apple Developer And App Store Connect",
    "## Provisioning, Export, And Upload",
    "## Screenshots",
    "## Final Store URL",
    "PEEK_GA_MEASUREMENT_ID=G-XXXXXXXXXX",
    "PEEK_BING_SITE_VERIFICATION=bing_token",
    "PEEK_CHECK_EXPORT=1",
    "Delivery UUID",
    "build-status = VALID",
    "APP_STORE_ELIGIBLE",
    "./script/capture_app_store_screenshot.sh",
    "./script/configure_app_store_url.py --dry-run",
    "com.shifeng.peek",
    "corner-peek-macos-001",
    "US$5.99",
    "Manual release",
    "Y4FV6WUU4V",
    "G-...",
    "msvalidate.01",
]

FORBIDDEN_COPY = [
    re.compile(pattern, re.IGNORECASE)
    for pattern in [
        r"\bTODO\b",
        r"\bTBD\b",
        r"Lorem ipsum",
        r"password\s*[:=]",
        r"api[_ -]?private[_ -]?key\s*[:=]",
    ]
]


def main() -> int:
    errors: list[str] = []
    if not INPUTS_PATH.exists():
        print(f"External launch inputs missing: {INPUTS_PATH}", file=sys.stderr)
        return 1

    text = INPUTS_PATH.read_text(encoding="utf-8")

    for marker in REQUIRED_MARKERS:
        if marker not in text:
            errors.append(f"missing marker: {marker!r}")

    unchecked_count = text.count("- [ ]")
    checked_count = text.count("- [x]")
    checklist_count = unchecked_count + checked_count
    print(f"external_inputs.unchecked_count: {unchecked_count}")
    print(f"external_inputs.checked_count: {checked_count}")
    if checklist_count < 13:
        errors.append(f"expected at least 13 checklist items, found {checklist_count}")

    required_unchecked_items = [
        "- [ ] Google Search Console sitemap status.",
        "- [ ] Bing Webmaster Tools.",
        "- [ ] Paid Apps Agreement, tax, and banking.",
        "- [ ] True Mac App Store URL.",
    ]
    for item in required_unchecked_items:
        if item not in text:
            errors.append(f"missing required unchecked item: {item}")

    for pattern in FORBIDDEN_COPY:
        match = pattern.search(text)
        if match:
            errors.append(f"contains forbidden or placeholder copy: {match.group(0)!r}")

    if errors:
        print("\nExternal launch inputs validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nExternal launch inputs validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
