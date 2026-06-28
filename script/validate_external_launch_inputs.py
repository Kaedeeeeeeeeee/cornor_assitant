#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INPUTS_PATH = ROOT / "CornerAssistantApp" / "docs" / "External-Launch-Inputs.md"

REQUIRED_MARKERS = [
    "# Peek External Launch Inputs",
    "## Analytics",
    "## Search Consoles",
    "## Apple Developer And App Store Connect",
    "## Provisioning, Export, And Upload",
    "## Screenshots",
    "## Final Store URL",
    "PEEK_GA_MEASUREMENT_ID=G-XXXXXXXXXX",
    "PEEK_BING_SITE_VERIFICATION=bing_token",
    "PEEK_CHECK_EXPORT=1 PEEK_ALLOW_PROVISIONING_UPDATES=1",
    "./script/capture_app_store_screenshot.sh",
    "./script/configure_app_store_url.py --dry-run",
    "com.shifeng.peek",
    "peek-macos-001",
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

    checkbox_count = text.count("- [ ]")
    print(f"external_inputs.checkbox_count: {checkbox_count}")
    if checkbox_count < 14:
        errors.append(f"expected at least 14 unchecked input items, found {checkbox_count}")

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
