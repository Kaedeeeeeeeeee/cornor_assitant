#!/usr/bin/env python3
from __future__ import annotations

import plistlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "CornerAssistantApp"
PRIVACY_MANIFEST_PATH = APP_DIR / "CornerAssistantApp" / "PrivacyInfo.xcprivacy"
PROJECT_PATH = APP_DIR / "CornerAssistantApp.xcodeproj" / "project.pbxproj"
MATERIALS_PATH = APP_DIR / "docs" / "AppStore-Materials.md"
LANDING_MAIN_PATH = APP_DIR / "landing-page" / "main.js"
LANDING_PRIVACY_PATH = APP_DIR / "landing-page" / "privacy.html"


EXPECTED_PRIVACY_MANIFEST = {
    "NSPrivacyTracking": False,
    "NSPrivacyTrackingDomains": [],
    "NSPrivacyCollectedDataTypes": [],
    "NSPrivacyAccessedAPITypes": [
        {
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": ["CA92.1"],
        }
    ],
}

PROJECT_SETTINGS = [
    ("PRODUCT_BUNDLE_IDENTIFIER", "com.shifeng.peek", 2),
    ("PRODUCT_NAME", '"Corner Peek"', 2),
    ("INFOPLIST_KEY_ITSAppUsesNonExemptEncryption", "NO", 2),
    ("ENABLE_APP_SANDBOX", "YES", 2),
    ("ENABLE_HARDENED_RUNTIME", "YES", 2),
    ("ENABLE_OUTGOING_NETWORK_CONNECTIONS", "YES", 2),
    ("ENABLE_INCOMING_NETWORK_CONNECTIONS", "NO", 2),
    ("ENABLE_RESOURCE_ACCESS_AUDIO_INPUT", "YES", 2),
    ("ENABLE_RESOURCE_ACCESS_CAMERA", "NO", 2),
    ("ENABLE_RESOURCE_ACCESS_LOCATION", "NO", 2),
    ("ENABLE_USER_SELECTED_FILES", "NO", 2),
    ("RUNTIME_EXCEPTION_ALLOW_JIT", "NO", 2),
]

MATERIALS_MARKERS = [
    ("support email", "f.shera.09@gmail.com"),
    ("system requirement", "macOS 15.0"),
    ("no account", "No account required"),
    ("no app analytics SDK", "No in-app analytics or advertising SDK"),
    ("data collection", "Data Collection: No collected data by developer-operated servers."),
    ("tracking", "Tracking: No."),
    ("in-app analytics", "Analytics in app: No."),
    (
        "website analytics scope",
        "Website analytics on public landing page: not part of App binary; disclose on Privacy Policy page only.",
    ),
    ("unrestricted web access", "| Unrestricted Web Access | Yes |"),
    ("export compliance", "ITSAppUsesNonExemptEncryption = false"),
]

LANDING_MARKERS = [
    ("support email", "f.shera.09@gmail.com"),
    ("local app data", "personal app data stays on your Mac"),
    ("website analytics separate", "Website analytics are handled separately from the app"),
    (
        "no developer server collection",
        "does not send your name, email, location, browsing history, or usage behavior",
    ),
    ("local preferences", "preferences are stored locally on your Mac"),
    ("default search service", "default search service"),
    ("no audio recording", "Corner Peek itself does not record audio"),
    (
        "public website analytics only",
        "public website only and is not embedded in the macOS app",
    ),
]


def read_text(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"Missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8")


def validate_privacy_manifest(errors: list[str]) -> None:
    if not PRIVACY_MANIFEST_PATH.exists():
        manifest_path = PRIVACY_MANIFEST_PATH.relative_to(ROOT)
        errors.append(f"Missing privacy manifest: {manifest_path}")
        return

    with PRIVACY_MANIFEST_PATH.open("rb") as plist_file:
        actual = plistlib.load(plist_file)

    for key, expected in EXPECTED_PRIVACY_MANIFEST.items():
        value = actual.get(key)
        print(f"privacy_manifest.{key}: {value!r}")
        if value != expected:
            errors.append(f"privacy_manifest.{key} expected {expected!r}; got {value!r}")

    unexpected_keys = sorted(set(actual) - set(EXPECTED_PRIVACY_MANIFEST))
    if unexpected_keys:
        errors.append(f"privacy_manifest has unexpected keys: {', '.join(unexpected_keys)}")


def validate_project_settings(errors: list[str]) -> None:
    project = read_text(PROJECT_PATH)

    for key, value, minimum_count in PROJECT_SETTINGS:
        marker = f"{key} = {value};"
        count = project.count(marker)
        print(f"project_setting.{key}: count={count} expected>={minimum_count}")
        if count < minimum_count:
            errors.append(
                f"project_setting.{key} expected at least "
                f"{minimum_count} occurrences of {marker!r}"
            )
        if value in {"YES", "NO"}:
            opposite = "NO" if value == "YES" else "YES"
            opposite_marker = f"{key} = {opposite};"
            opposite_count = project.count(opposite_marker)
            print(f"project_setting.{key}.opposite_{opposite}: count={opposite_count} expected=0")
            if opposite_count:
                errors.append(
                    f"project_setting.{key} has {opposite_count} unexpected "
                    f"occurrence(s) of {opposite_marker!r}"
                )

    microphone_marker = (
        'INFOPLIST_KEY_NSMicrophoneUsageDescription = "Websites opened in Corner Peek may request '
        'microphone access for features such as calls or voice input.";'
    )
    microphone_count = project.count(microphone_marker)
    print(f"project_setting.NSMicrophoneUsageDescription: count={microphone_count} expected>=2")
    if microphone_count < 2:
        errors.append("NSMicrophoneUsageDescription does not match the launch privacy wording")


def validate_markers(
    label: str,
    text: str,
    markers: list[tuple[str, str]],
    errors: list[str],
) -> None:
    for marker_label, marker in markers:
        found = marker in text
        print(f"{label}.{marker_label}: {'ok' if found else 'missing'}")
        if not found:
            errors.append(f"{label}.{marker_label} missing marker: {marker!r}")


def validate_materials(errors: list[str]) -> None:
    materials = read_text(MATERIALS_PATH)
    validate_markers("materials", materials, MATERIALS_MARKERS, errors)


def validate_landing_privacy(errors: list[str]) -> None:
    landing_text = "\n".join([read_text(LANDING_MAIN_PATH), read_text(LANDING_PRIVACY_PATH)])
    validate_markers("landing_privacy", landing_text, LANDING_MARKERS, errors)


def validate() -> int:
    errors: list[str] = []

    try:
        validate_privacy_manifest(errors)
        validate_project_settings(errors)
        validate_materials(errors)
        validate_landing_privacy(errors)
    except FileNotFoundError as exc:
        errors.append(str(exc))

    if errors:
        print("\nPrivacy alignment validation errors:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nPrivacy alignment validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(validate())
