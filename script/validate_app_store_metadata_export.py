#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
DEFAULT_OUTPUT_DIR = Path("/tmp/peek-app-store-metadata")
MANUAL_QA_PATH = ROOT / "CornerAssistantApp" / "docs" / "Manual-QA-Checklist.md"
EXTERNAL_INPUTS_PATH = ROOT / "CornerAssistantApp" / "docs" / "External-Launch-Inputs.md"

sys.path.insert(0, str(SCRIPT_DIR))

from export_app_store_metadata import (  # noqa: E402
    FIELD_FILENAMES,
    build_app_information,
    extract_first_text_block,
    extract_heading_section,
)
from validate_app_store_materials import (  # noqa: E402
    LOCALIZATIONS,
    MATERIALS_PATH,
    extract_basic_info,
    extract_code_block_after_label,
    extract_localized_section,
)


FORBIDDEN_USER_COPY = [
    re.compile(pattern, re.IGNORECASE)
    for pattern in [
        r"\bBing\b",
        r"macOS\s*14",
        r"\bSonoma\b",
        r"selected[- ]text",
        r"选中文字",
        r"選択したテキスト",
        r"search engine choice",
        r"search engines? can be changed",
        r"搜索引擎可选",
        r"検索エンジンを選択",
        r"\bTBD\b",
        r"\bTODO\b",
        r"Lorem ipsum",
    ]
]

REQUIRED_INFO = {
    "app_name": "Peek",
    "bundle_id": "com.shifeng.peek",
    "sku": "peek-macos-001",
    "publisher": "Zhang Shifeng",
    "copyright": "2026 Zhang Shifeng",
    "category": "Productivity",
    "price": "US$5.99，一次买断",
    "minimum_macos": "macOS 15.0 或更高版本",
    "support_email": "f.shera.09@gmail.com",
    "marketing_url": "https://kaedeeeeeeeeee.github.io/cornor_assitant/",
    "privacy_policy_url": "https://kaedeeeeeeeeee.github.io/cornor_assitant/privacy.html",
    "support_url": "https://kaedeeeeeeeeee.github.io/cornor_assitant/support.html",
    "primary_language": "English (U.S.)",
    "release_option": "Manually release this version",
    "distribution_method": "Public Distribution",
    "license_agreement": "Apple Standard EULA",
}


def read_text(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(f"missing file: {path}")
    return path.read_text(encoding="utf-8")


def validate_no_forbidden_copy(label: str, value: str, errors: list[str]) -> None:
    for pattern in FORBIDDEN_USER_COPY:
        match = pattern.search(value)
        if match:
            errors.append(f"{label} contains forbidden or placeholder copy: {match.group(0)!r}")


def expected_files() -> set[Path]:
    files = {
        Path("README.md"),
        Path("app_information.json"),
        Path("app_review_notes.txt"),
        Path("app_store_connect_submission_checklist.md"),
        Path("manual_qa_checklist.md"),
        Path("external_launch_inputs.md"),
    }
    for locale, config in LOCALIZATIONS.items():
        for field in config["fields"]:
            files.add(Path("metadata") / locale / FIELD_FILENAMES[field.key])
    return files


def validate_file_set(output_dir: Path, errors: list[str]) -> None:
    actual = {path.relative_to(output_dir) for path in output_dir.rglob("*") if path.is_file()}
    expected = expected_files()
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)

    for path in missing:
        errors.append(f"metadata export missing file: {path}")
    for path in unexpected:
        errors.append(f"metadata export has unexpected file: {path}")


def validate_app_information(output_dir: Path, markdown: str, errors: list[str]) -> None:
    path = output_dir / "app_information.json"
    try:
        actual = json.loads(read_text(path))
    except Exception as exc:  # noqa: BLE001 - report all export issues in one pass.
        errors.append(f"could not parse app_information.json: {exc}")
        return

    expected = build_app_information(extract_basic_info(markdown))
    if actual != expected:
        errors.append("app_information.json does not match current AppStore-Materials.md")

    for key, expected_value in REQUIRED_INFO.items():
        actual_value = actual.get(key)
        print(f"metadata_export.app_information.{key}: {actual_value!r}")
        if actual_value != expected_value:
            errors.append(f"app_information.{key} expected {expected_value!r}; got {actual_value!r}")

    privacy = actual.get("app_privacy")
    if privacy != {
        "tracking": False,
        "data_collected_by_developer": False,
        "in_app_analytics": False,
        "third_party_advertising": False,
    }:
        errors.append("app_information.app_privacy does not match launch privacy policy")

    age_rating = actual.get("age_rating_notes")
    if not isinstance(age_rating, dict) or age_rating.get("unrestricted_web_access") is not True:
        errors.append("app_information.age_rating_notes.unrestricted_web_access must be true")

    manual_fields = actual.get("manual_fields")
    for required in [
        "Paid Apps Agreement, tax, and banking",
        "Real App Review contact phone",
        "EU DSA trader status if selling in EU",
        "Screenshots",
        "Uploaded build selection",
    ]:
        if not isinstance(manual_fields, list) or required not in manual_fields:
            errors.append(f"app_information.manual_fields missing {required!r}")


def validate_localized_metadata(output_dir: Path, markdown: str, errors: list[str]) -> None:
    for locale, config in LOCALIZATIONS.items():
        section = extract_localized_section(markdown, config["heading"])
        for field in config["fields"]:
            relative_path = Path("metadata") / locale / FIELD_FILENAMES[field.key]
            path = output_dir / relative_path
            try:
                actual = read_text(path).rstrip("\n")
            except FileNotFoundError as exc:
                errors.append(str(exc))
                continue
            expected = extract_code_block_after_label(section, field.label)
            char_count = len(actual)
            byte_count = len(actual.encode("utf-8"))
            print(f"metadata_export.{locale}.{field.key}: chars={char_count} bytes={byte_count}")
            if actual != expected:
                errors.append(f"{relative_path} does not match current AppStore-Materials.md")
            if not actual:
                errors.append(f"{relative_path} is empty")
            if field.char_limit is not None and char_count > field.char_limit:
                errors.append(f"{relative_path} has {char_count} chars; limit is {field.char_limit}")
            if field.byte_limit is not None and byte_count > field.byte_limit:
                errors.append(f"{relative_path} has {byte_count} bytes; limit is {field.byte_limit}")
            validate_no_forbidden_copy(str(relative_path), actual, errors)


def validate_review_notes(output_dir: Path, markdown: str, errors: list[str]) -> None:
    section = extract_heading_section(markdown, "App Review Notes 草稿")
    expected = extract_first_text_block(section, "App Review Notes")
    actual = read_text(output_dir / "app_review_notes.txt").rstrip("\n")
    print(f"metadata_export.app_review_notes: chars={len(actual)}")
    if actual != expected:
        errors.append("app_review_notes.txt does not match current AppStore-Materials.md")
    for marker in [
        "Peek is a macOS menu bar utility. It does not require an account.",
        "Move the cursor to the configured hot corner",
        "f.shera.09@gmail.com",
    ]:
        if marker not in actual:
            errors.append(f"app_review_notes.txt missing marker: {marker!r}")
    validate_no_forbidden_copy("app_review_notes.txt", actual, errors)


def validate_readme_and_checklist(output_dir: Path, errors: list[str]) -> None:
    readme = read_text(output_dir / "README.md")
    checklist = read_text(output_dir / "app_store_connect_submission_checklist.md")
    manual_qa = read_text(output_dir / "manual_qa_checklist.md")
    external_inputs = read_text(output_dir / "external_launch_inputs.md")
    for label, text, markers in [
        (
            "README.md",
            readme,
            [
                "Manual Fields Still Required",
                "Paid Apps Agreement, tax, and banking",
                "manual_qa_checklist.md",
                "external_launch_inputs.md",
                "Do not submit screenshots or binaries from this export folder.",
            ],
        ),
        (
            "app_store_connect_submission_checklist.md",
            checklist,
            [
                "Bundle ID: `com.shifeng.peek`",
                "Price: US$5.99，一次买断",
                "Privacy Policy URL: https://kaedeeeeeeeeee.github.io/cornor_assitant/privacy.html",
                "App Store Connect fields",
                "Screenshot plan",
                "Pre-submission checklist",
            ],
        ),
        (
            "manual_qa_checklist.md",
            manual_qa,
            [
                "# Peek Manual QA Checklist",
                "### 菜单栏图标点击",
                "### WebKit 常见登录页面",
                "## 当前已知人工阻塞",
            ],
        ),
        (
            "external_launch_inputs.md",
            external_inputs,
            [
                "# Peek External Launch Inputs",
                "## Analytics",
                "## Apple Developer And App Store Connect",
                "## Final Store URL",
            ],
        ),
    ]:
        print(f"metadata_export.{label}: chars={len(text)}")
        for marker in markers:
            if marker not in text:
                errors.append(f"{label} missing marker: {marker!r}")

    if manual_qa != MANUAL_QA_PATH.read_text(encoding="utf-8"):
        errors.append("manual_qa_checklist.md does not match current Manual-QA-Checklist.md")
    if external_inputs != EXTERNAL_INPUTS_PATH.read_text(encoding="utf-8"):
        errors.append("external_launch_inputs.md does not match current External-Launch-Inputs.md")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a generated Peek App Store metadata export package.")
    parser.add_argument(
        "output_dir",
        nargs="?",
        default=str(DEFAULT_OUTPUT_DIR),
        help="Directory generated by export_app_store_metadata.py",
    )
    args = parser.parse_args()

    output_dir = Path(args.output_dir).expanduser()
    if not output_dir.is_absolute():
        output_dir = ROOT / output_dir

    errors: list[str] = []
    try:
        if not output_dir.is_dir():
            errors.append(f"metadata export directory is missing: {output_dir}")
        else:
            markdown = MATERIALS_PATH.read_text(encoding="utf-8")
            validate_file_set(output_dir, errors)
            validate_app_information(output_dir, markdown, errors)
            validate_localized_metadata(output_dir, markdown, errors)
            validate_review_notes(output_dir, markdown, errors)
            validate_readme_and_checklist(output_dir, errors)
    except Exception as exc:  # noqa: BLE001 - this is a CLI verifier.
        errors.append(str(exc))

    if errors:
        print("\nApp Store metadata export validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nApp Store metadata export validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
