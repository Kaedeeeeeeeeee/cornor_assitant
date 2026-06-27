#!/usr/bin/env python3
from __future__ import annotations

import plistlib
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXPORT_OPTIONS_PATH = ROOT / "CornerAssistantApp" / "export_options_app_store.plist"

EXPECTED_EXPORT_OPTIONS = {
    "destination": "export",
    "method": "app-store-connect",
    "signingCertificate": "Apple Distribution",
    "signingStyle": "automatic",
    "stripSwiftSymbols": True,
    "uploadSymbols": True,
}


def main() -> int:
    errors: list[str] = []
    if not EXPORT_OPTIONS_PATH.exists():
        errors.append(f"Missing export options plist: {EXPORT_OPTIONS_PATH.relative_to(ROOT)}")
    else:
        with EXPORT_OPTIONS_PATH.open("rb") as file:
            options = plistlib.load(file)

        if not isinstance(options, dict):
            errors.append("export options root is not a dictionary")
            options = {}

        for key, expected in EXPECTED_EXPORT_OPTIONS.items():
            actual = options.get(key)
            print(f"export_options.{key}: {actual!r}")
            if actual != expected:
                errors.append(f"export_options.{key} expected {expected!r}; got {actual!r}")

        team_id = options.get("teamID")
        print(f"export_options.teamID: {team_id!r}")
        if not isinstance(team_id, str) or not re.fullmatch(r"[A-Z0-9]{10}", team_id):
            errors.append("export_options.teamID must be a 10-character Apple team id")

        allowed_keys = set(EXPECTED_EXPORT_OPTIONS) | {"teamID"}
        unexpected_keys = sorted(set(options) - allowed_keys)
        if unexpected_keys:
            errors.append(f"export options has unexpected keys: {', '.join(unexpected_keys)}")

    if errors:
        print("\nExport options validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nExport options validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
