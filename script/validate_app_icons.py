#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import struct
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_ICONSET_DIR = ROOT / "CornerAssistantApp" / "CornerAssistantApp" / "Assets.xcassets" / "AppIcon.appiconset"
APP_ICON_CONTENTS = APP_ICONSET_DIR / "Contents.json"
APP_MARKETING_ICON = APP_ICONSET_DIR / "icon_512x512_2x.png"
LANDING_DIR = ROOT / "CornerAssistantApp" / "landing-page"
LANDING_ICON = LANDING_DIR / "assets" / "icon.png"
SOCIAL_PREVIEW = LANDING_DIR / "assets" / "social-preview.png"
MANIFEST_PATH = LANDING_DIR / "site.webmanifest"
LANDING_PAGES = [
    LANDING_DIR / "index.html",
    LANDING_DIR / "privacy.html",
    LANDING_DIR / "support.html",
]
EXPECTED_SOCIAL_PREVIEW_SIZE = (1200, 630)


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as file:
        header = file.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"not a PNG file: {path}")
    return struct.unpack(">II", header[16:24])


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_size(value: str) -> tuple[int, int]:
    width, height = value.split("x", 1)
    return int(width), int(height)


def parse_scale(value: str) -> int:
    if not value.endswith("x"):
        raise ValueError(f"unexpected scale: {value}")
    return int(value[:-1])


def validate_app_iconset(errors: list[str]) -> None:
    contents = json.loads(APP_ICON_CONTENTS.read_text(encoding="utf-8"))
    images = contents.get("images")
    if not isinstance(images, list):
        errors.append("AppIcon Contents.json does not contain an images array")
        return
    if len(images) != 10:
        errors.append(f"AppIcon Contents.json expected 10 images, got {len(images)}")

    seen_files: set[str] = set()
    for image in images:
        if not isinstance(image, dict):
            errors.append(f"AppIcon image entry is not an object: {image!r}")
            continue
        filename = image.get("filename")
        size = image.get("size")
        scale = image.get("scale")
        idiom = image.get("idiom")
        if not isinstance(filename, str) or not isinstance(size, str) or not isinstance(scale, str):
            errors.append(f"AppIcon image entry is missing filename/size/scale: {image!r}")
            continue
        if idiom != "mac":
            errors.append(f"AppIcon {filename} idiom expected mac, got {idiom!r}")

        path = APP_ICONSET_DIR / filename
        if not path.exists():
            errors.append(f"AppIcon image missing: {path}")
            continue
        seen_files.add(filename)

        try:
            base_width, base_height = parse_size(size)
            multiplier = parse_scale(scale)
            actual_size = png_size(path)
        except Exception as exc:  # noqa: BLE001 - report all asset validation issues.
            errors.append(f"AppIcon {filename} could not be validated: {exc}")
            continue

        expected_size = (base_width * multiplier, base_height * multiplier)
        print(f"app_icon.{filename}: {actual_size[0]}x{actual_size[1]}")
        if actual_size != expected_size:
            errors.append(f"AppIcon {filename} expected {expected_size[0]}x{expected_size[1]}, got {actual_size[0]}x{actual_size[1]}")

    unlisted = {path.name for path in APP_ICONSET_DIR.glob("*.png")} - seen_files
    if unlisted:
        errors.append(f"AppIcon has unlisted PNG files: {', '.join(sorted(unlisted))}")


def validate_landing_icons(errors: list[str]) -> None:
    landing_size = png_size(LANDING_ICON)
    marketing_size = png_size(APP_MARKETING_ICON)
    social_size = png_size(SOCIAL_PREVIEW)
    landing_hash = sha256(LANDING_ICON)
    marketing_hash = sha256(APP_MARKETING_ICON)

    print(f"landing.icon: {landing_size[0]}x{landing_size[1]} sha256={landing_hash}")
    print(f"app_icon.marketing: {marketing_size[0]}x{marketing_size[1]} sha256={marketing_hash}")
    print(f"landing.social_preview: {social_size[0]}x{social_size[1]}")

    if landing_size != (1024, 1024):
        errors.append(f"landing icon expected 1024x1024, got {landing_size[0]}x{landing_size[1]}")
    if marketing_size != (1024, 1024):
        errors.append(f"AppIcon 512@2x expected 1024x1024, got {marketing_size[0]}x{marketing_size[1]}")
    if landing_hash != marketing_hash:
        errors.append("landing icon is not byte-identical to Xcode AppIcon 512@2x image")
    if social_size != EXPECTED_SOCIAL_PREVIEW_SIZE:
        errors.append(f"social preview expected 1200x630, got {social_size[0]}x{social_size[1]}")


def validate_manifest(errors: list[str]) -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    icons = manifest.get("icons")
    if not isinstance(icons, list):
        errors.append("site.webmanifest does not contain an icons array")
        return

    matching_icons = [
        icon for icon in icons
        if isinstance(icon, dict) and icon.get("src") == "assets/icon.png"
    ]
    if not matching_icons:
        errors.append("site.webmanifest does not reference assets/icon.png")
        return

    sizes = {
        size
        for icon in matching_icons
        for size in str(icon.get("sizes", "")).split()
    }
    if "1024x1024" not in sizes:
        errors.append("site.webmanifest assets/icon.png entry does not declare 1024x1024")
    for icon in matching_icons:
        if icon.get("type") != "image/png":
            errors.append(f"site.webmanifest icon type expected image/png, got {icon.get('type')!r}")


def validate_landing_page_references(errors: list[str]) -> None:
    required = [
        '<link rel="icon" type="image/png" href="assets/icon.png">',
        '<link rel="apple-touch-icon" href="assets/icon.png">',
        '<link rel="manifest" href="site.webmanifest">',
        'content="https://kaedeeeeeeeeee.github.io/cornor_assitant/assets/social-preview.png"',
    ]
    for page in LANDING_PAGES:
        text = page.read_text(encoding="utf-8")
        for marker in required:
            if marker not in text:
                errors.append(f"{page.relative_to(ROOT)} missing marker: {marker}")


def main() -> int:
    errors: list[str] = []
    try:
        validate_app_iconset(errors)
        validate_landing_icons(errors)
        validate_manifest(errors)
        validate_landing_page_references(errors)
    except Exception as exc:  # noqa: BLE001 - this is a CLI verifier.
        errors.append(str(exc))

    if errors:
        print("\nApp icon validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nApp icon validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
