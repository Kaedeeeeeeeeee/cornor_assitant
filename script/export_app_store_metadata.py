#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
DEFAULT_OUTPUT_DIR = Path("/tmp/peek-app-store-metadata")
MANUAL_QA_PATH = ROOT / "CornerAssistantApp" / "docs" / "Manual-QA-Checklist.md"
EXTERNAL_INPUTS_PATH = ROOT / "CornerAssistantApp" / "docs" / "External-Launch-Inputs.md"

sys.path.insert(0, str(SCRIPT_DIR))

from validate_app_store_materials import (  # noqa: E402
    LOCALIZATIONS,
    MATERIALS_PATH,
    extract_basic_info,
    extract_code_block_after_label,
    extract_localized_section,
    validate,
)


FIELD_FILENAMES = {
    "app_name": "app_name.txt",
    "subtitle": "subtitle.txt",
    "description": "description.txt",
    "keywords": "keywords.txt",
    "whats_new": "whats_new.txt",
}

LOCALE_DISPLAY_NAMES = {
    "zh-Hans": "Chinese (Simplified)",
    "en-US": "English (U.S.)",
    "ja": "Japanese",
}


def strip_inline_code(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value.startswith("`") and value.endswith("`"):
        return value[1:-1]
    return value


def extract_heading_section(markdown: str, heading: str) -> str:
    pattern = re.compile(rf"^## {re.escape(heading)}\s*$", re.MULTILINE)
    match = pattern.search(markdown)
    if not match:
        raise ValueError(f"Missing heading: {heading}")

    start = match.end()
    next_heading = re.search(r"^## .+$", markdown[start:], re.MULTILINE)
    end = start + next_heading.start() if next_heading else len(markdown)
    return markdown[start:end]


def extract_first_text_block(section: str, label: str) -> str:
    block = re.search(r"```text\n(.*?)\n```", section, re.DOTALL)
    if not block:
        raise ValueError(f"Missing text code block in: {label}")
    return block.group(1).strip()


def build_app_information(basic_info: dict[str, str]) -> dict[str, object]:
    return {
        "app_name": basic_info["App 名称"],
        "bundle_id": strip_inline_code(basic_info["Bundle ID"]),
        "sku": strip_inline_code(basic_info["SKU 建议"]),
        "publisher": basic_info["发布者/版权"],
        "copyright": "2026 Zhang Shifeng",
        "category": basic_info["分类"],
        "price": basic_info["价格"],
        "minimum_macos": basic_info["系统要求"],
        "support_email": strip_inline_code(basic_info["支持邮箱"]),
        "marketing_url": strip_inline_code(basic_info["Marketing URL"]),
        "privacy_policy_url": strip_inline_code(basic_info["Privacy Policy URL"]),
        "support_url": strip_inline_code(basic_info["Support URL"]),
        "primary_language": "English (U.S.)",
        "localizations": [LOCALE_DISPLAY_NAMES[locale] for locale in LOCALIZATIONS],
        "sign_in_required": False,
        "demo_account": None,
        "in_app_purchases": False,
        "subscriptions": False,
        "release_option": "Manually release this version",
        "distribution_method": "Public Distribution",
        "reference_country_or_region": "United States",
        "availability": "All Countries or Regions unless compliance requires exclusions",
        "license_agreement": "Apple Standard EULA",
        "app_privacy": {
            "tracking": False,
            "data_collected_by_developer": False,
            "in_app_analytics": False,
            "third_party_advertising": False,
        },
        "age_rating_notes": {
            "made_for_kids": False,
            "unrestricted_web_access": True,
            "expected_rating_note": "App Store Connect calculates the final age rating.",
        },
        "export_compliance": {
            "ITSAppUsesNonExemptEncryption": False,
            "notes": "Uses Apple system networking/WebKit; no custom encryption implementation.",
        },
        "manual_fields": [
            "Paid Apps Agreement, tax, and banking",
            "Real App Review contact phone",
            "EU DSA trader status if selling in EU",
            "Screenshots",
            "Uploaded build selection",
        ],
    }


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value.rstrip() + "\n", encoding="utf-8")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_readme(output_dir: Path, app_information: dict[str, object]) -> None:
    lines = [
        "# Corner Peek App Store Metadata Export",
        "",
        f"Source: `{MATERIALS_PATH}`",
        "",
        "Use this package as copy-paste material for App Store Connect after the Apple account, app record, and provisioning profile are ready.",
        "",
        "## Files",
        "",
        "- `app_information.json`: shared app record, pricing, privacy, age-rating, and compliance notes.",
        "- `app_store_connect_submission_checklist.md`: copy-paste checklist for App Store Connect forms.",
        "- `manual_qa_checklist.md`: manual QA checklist for the clean desktop and App Store screenshot pass.",
        "- `external_launch_inputs.md`: external account, credential, and final URL inputs that still need the account holder.",
        "- `app_review_notes.txt`: App Review notes draft.",
        "- `metadata/<locale>/app_name.txt`",
        "- `metadata/<locale>/subtitle.txt`",
        "- `metadata/<locale>/description.txt`",
        "- `metadata/<locale>/keywords.txt`",
        "- `metadata/<locale>/whats_new.txt`",
        "",
        "## Localizations",
        "",
    ]

    for locale in LOCALIZATIONS:
        lines.append(f"- `{locale}`: {LOCALE_DISPLAY_NAMES[locale]}")

    lines.extend(
        [
            "",
            "## Manual Fields Still Required",
            "",
        ]
    )

    for field in app_information["manual_fields"]:
        lines.append(f"- {field}")

    lines.extend(
        [
            "",
            "## Validation",
            "",
            "Run from the repository root before pasting or submitting:",
            "",
            "```bash",
            "./script/validate_app_store_materials.py",
            "./script/launch_verify.sh",
            "```",
            "",
            "Do not submit screenshots or binaries from this export folder. Use the screenshot and archive workflows in `CornerAssistantApp/docs/Launch-Plan.md`.",
            "",
        ]
    )

    write_text(output_dir / "README.md", "\n".join(lines))


def write_submission_checklist(
    output_dir: Path,
    markdown: str,
    app_information: dict[str, object],
) -> None:
    included_sections = [
        ("App Store Connect fields", "App Store Connect 字段建议"),
        ("Export compliance", "Export Compliance 建议填写"),
        ("Screenshot plan", "截图计划"),
        ("Pre-submission checklist", "上架前核对"),
    ]
    lines = [
        "# Corner Peek App Store Connect Submission Checklist",
        "",
        f"Source: `{MATERIALS_PATH}`",
        "",
        "Use this file while filling App Store Connect. It is generated from the reviewed launch materials, but the account holder must still confirm any legal, tax, banking, DSA, and contact details in Apple's UI.",
        "",
        "## Snapshot",
        "",
        f"- App name: {app_information['app_name']}",
        f"- Bundle ID: `{app_information['bundle_id']}`",
        f"- SKU: `{app_information['sku']}`",
        f"- Price: {app_information['price']}",
        f"- Primary language: {app_information['primary_language']}",
        f"- Marketing URL: {app_information['marketing_url']}",
        f"- Privacy Policy URL: {app_information['privacy_policy_url']}",
        f"- Support URL: {app_information['support_url']}",
        f"- Release option: {app_information['release_option']}",
        "",
        "## Files to paste",
        "",
        "- Localized metadata: `metadata/<locale>/*.txt`",
        "- App Review notes: `app_review_notes.txt`",
        "- Shared app record data: `app_information.json`",
        "",
    ]

    for title, heading in included_sections:
        section = extract_heading_section(markdown, heading).strip()
        lines.extend([f"## {title}", "", section, ""])

    write_text(output_dir / "app_store_connect_submission_checklist.md", "\n".join(lines))


def export_metadata(output_dir: Path) -> list[Path]:
    markdown = MATERIALS_PATH.read_text(encoding="utf-8")
    basic_info = extract_basic_info(markdown)
    written: list[Path] = []

    app_information = build_app_information(basic_info)
    info_path = output_dir / "app_information.json"
    write_json(info_path, app_information)
    written.append(info_path)

    for locale, config in LOCALIZATIONS.items():
        section = extract_localized_section(markdown, config["heading"])
        locale_dir = output_dir / "metadata" / locale
        for field in config["fields"]:
            value = extract_code_block_after_label(section, field.label)
            path = locale_dir / FIELD_FILENAMES[field.key]
            write_text(path, value)
            written.append(path)

    review_notes_section = extract_heading_section(markdown, "App Review Notes 草稿")
    review_notes = extract_first_text_block(review_notes_section, "App Review Notes")
    review_path = output_dir / "app_review_notes.txt"
    write_text(review_path, review_notes)
    written.append(review_path)

    checklist_path = output_dir / "app_store_connect_submission_checklist.md"
    write_submission_checklist(output_dir, markdown, app_information)
    written.append(checklist_path)

    manual_qa_path = output_dir / "manual_qa_checklist.md"
    write_text(manual_qa_path, MANUAL_QA_PATH.read_text(encoding="utf-8"))
    written.append(manual_qa_path)

    external_inputs_path = output_dir / "external_launch_inputs.md"
    write_text(external_inputs_path, EXTERNAL_INPUTS_PATH.read_text(encoding="utf-8"))
    written.append(external_inputs_path)

    readme_path = output_dir / "README.md"
    write_readme(output_dir, app_information)
    written.append(readme_path)

    return written


def main() -> int:
    output_dir = Path(os.environ.get("OUT_DIR", str(DEFAULT_OUTPUT_DIR))).expanduser()
    if not output_dir.is_absolute():
        output_dir = ROOT / output_dir
    if output_dir.exists() and not output_dir.is_dir():
        print(f"Output path exists and is not a directory: {output_dir}", file=sys.stderr)
        return 1

    validation_status = validate()
    if validation_status != 0:
        return validation_status

    written = export_metadata(output_dir)
    print(f"\nExported App Store metadata package: {output_dir}")
    for path in sorted(written):
        print(f"- {path.relative_to(output_dir)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
