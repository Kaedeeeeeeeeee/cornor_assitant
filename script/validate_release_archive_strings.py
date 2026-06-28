#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_APP_PATH = Path("/tmp/peek-appstore/Corner Peek.xcarchive/Products/Applications/Corner Peek.app")


@dataclass(frozen=True)
class ForbiddenPattern:
    label: str
    pattern: re.Pattern[str]


FORBIDDEN_EXECUTABLE_PATTERNS = [
    ForbiddenPattern(
        "debug panel command notification",
        re.compile(r"com\.shifeng\.peek\.debug\.panelCommand"),
    ),
    ForbiddenPattern(
        "debug hot corner command",
        re.compile(r"corner:"),
    ),
    ForbiddenPattern(
        "debug screenshot scenario command",
        re.compile(r"scenario:"),
    ),
    ForbiddenPattern(
        "unused Bing search provider",
        re.compile(r"BingSearchProvider|bing\.com|api\.bing", re.IGNORECASE),
    ),
    ForbiddenPattern(
        "unused OCR history code",
        re.compile(r"OCRHistoryManager|OCRHistoryItem|OCRHistory", re.IGNORECASE),
    ),
]

FORBIDDEN_RESOURCE_PATTERNS = [
    ForbiddenPattern("Bing public copy", re.compile(r"\bBing\b", re.IGNORECASE)),
    ForbiddenPattern("selected text public copy", re.compile(r"selected[- ]text", re.IGNORECASE)),
    ForbiddenPattern("selected text public copy zh", re.compile(r"选中文字")),
    ForbiddenPattern("selected text public copy ja", re.compile(r"選択したテキスト")),
    ForbiddenPattern("macOS 14 public copy", re.compile(r"macOS\s*14", re.IGNORECASE)),
    ForbiddenPattern("Sonoma public copy", re.compile(r"\bSonoma\b", re.IGNORECASE)),
]


def run_strings(path: Path) -> str:
    strings_path = shutil.which("strings")
    if not strings_path:
        raise ValueError("strings command is not available")

    result = subprocess.run(
        [strings_path, str(path)],
        text=True,
        capture_output=True,
        check=False,
        timeout=30,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise ValueError(f"strings failed for {path}: {detail}")
    return result.stdout


def app_executable_path(app_path: Path) -> Path:
    info_plist = app_path / "Contents" / "Info.plist"
    executable = app_path / "Contents" / "MacOS" / "Corner Peek"
    if not app_path.is_dir():
        raise ValueError(f"app bundle is missing: {app_path}")
    if not info_plist.exists():
        raise ValueError(f"Info.plist is missing: {info_plist}")
    if not executable.exists():
        raise ValueError(f"executable is missing: {executable}")
    return executable


def validate_text(
    text: str,
    patterns: list[ForbiddenPattern],
    context: str,
    errors: list[str],
) -> None:
    for forbidden in patterns:
        match = forbidden.pattern.search(text)
        if match:
            snippet = match.group(0)
            errors.append(f"{context} contains {forbidden.label}: {snippet!r}")


def validate_localized_resources(app_path: Path, errors: list[str]) -> None:
    resource_dir = app_path / "Contents" / "Resources"
    strings_files = sorted(resource_dir.glob("*.lproj/Localizable.strings"))
    if not strings_files:
        errors.append(f"no localized strings files found under {resource_dir}")
        return

    for path in strings_files:
        raw = path.read_bytes()
        for encoding in ("utf-8-sig", "utf-16"):
            try:
                text = raw.decode(encoding)
                break
            except UnicodeDecodeError:
                continue
        else:
            errors.append(f"could not decode localized strings file: {path}")
            continue
        label = str(path.relative_to(app_path))
        validate_text(text, FORBIDDEN_RESOURCE_PATTERNS, label, errors)
        print(f"release_strings.resource: {label}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate that the archived Corner Peek app does not contain debug-only or unsupported launch strings."
    )
    parser.add_argument(
        "app_path",
        nargs="?",
        default=str(DEFAULT_APP_PATH),
        help="Path to archived/exported Corner Peek.app",
    )
    args = parser.parse_args()

    app_path = Path(args.app_path).expanduser()
    if not app_path.is_absolute():
        app_path = ROOT / app_path

    errors: list[str] = []
    try:
        executable = app_executable_path(app_path)
        executable_strings = run_strings(executable)
        validate_text(executable_strings, FORBIDDEN_EXECUTABLE_PATTERNS, str(executable), errors)
        validate_localized_resources(app_path, errors)
        print(f"release_strings.executable: {executable}")
    except Exception as exc:  # noqa: BLE001 - this is a CLI verifier.
        errors.append(str(exc))

    if errors:
        print("\nRelease archive string validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nRelease archive string validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
