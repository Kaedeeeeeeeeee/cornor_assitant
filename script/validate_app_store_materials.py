#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MATERIALS_PATH = ROOT / "CornerAssistantApp" / "docs" / "AppStore-Materials.md"


@dataclass(frozen=True)
class Field:
    key: str
    label: str
    char_limit: int | None = None
    byte_limit: int | None = None


LOCALIZATIONS = {
    "zh-Hans": {
        "heading": "中文（简体）",
        "fields": [
            Field("app_name", "App 名称", char_limit=30),
            Field("subtitle", "副标题", char_limit=30),
            Field("description", "描述", char_limit=4000),
            Field("keywords", "关键词", byte_limit=100),
            Field("whats_new", "新功能", char_limit=4000),
        ],
    },
    "en-US": {
        "heading": "English",
        "fields": [
            Field("app_name", "App Name", char_limit=30),
            Field("subtitle", "Subtitle", char_limit=30),
            Field("description", "Description", char_limit=4000),
            Field("keywords", "Keywords", byte_limit=100),
            Field("whats_new", "What's New", char_limit=4000),
        ],
    },
    "ja": {
        "heading": "日本語",
        "fields": [
            Field("app_name", "App 名", char_limit=30),
            Field("subtitle", "サブタイトル", char_limit=30),
            Field("description", "説明", char_limit=4000),
            Field("keywords", "キーワード", byte_limit=100),
            Field("whats_new", "新機能", char_limit=4000),
        ],
    },
}

FORBIDDEN_PATTERNS = [
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
    ]
]

BASIC_INFO_EXPECTATIONS = {
    "App 名称": "Peek",
    "Bundle ID": "`com.shifeng.peek`",
    "SKU 建议": "`peek-macos-001`",
    "发布者/版权": "Zhang Shifeng",
    "分类": "Productivity",
    "价格": "US$5.99，一次买断",
    "系统要求": "macOS 15.0 或更高版本",
    "支持邮箱": "`f.shera.09@gmail.com`",
    "Marketing URL": "`https://kaedeeeeeeeeee.github.io/cornor_assitant/`",
    "Privacy Policy URL": "`https://kaedeeeeeeeeee.github.io/cornor_assitant/privacy.html`",
    "Support URL": "`https://kaedeeeeeeeeee.github.io/cornor_assitant/support.html`",
}


def extract_localized_section(markdown: str, heading: str) -> str:
    pattern = re.compile(rf"^### {re.escape(heading)}\s*$", re.MULTILINE)
    match = pattern.search(markdown)
    if not match:
        raise ValueError(f"Missing localization heading: {heading}")

    start = match.end()
    next_heading = re.search(r"^### .+$", markdown[start:], re.MULTILINE)
    end = start + next_heading.start() if next_heading else len(markdown)
    return markdown[start:end]


def extract_code_block_after_label(section: str, label: str) -> str:
    label_pattern = re.compile(rf"^{re.escape(label)}[^:\n]*[:：]\s*$", re.MULTILINE)
    match = label_pattern.search(section)
    if not match:
        raise ValueError(f"Missing field label: {label}")

    block = re.search(r"```text\n(.*?)\n```", section[match.end():], re.DOTALL)
    if not block:
        raise ValueError(f"Missing text code block after: {label}")
    return block.group(1).strip()


def extract_basic_info(markdown: str) -> dict[str, str]:
    heading = re.search(r"^## 基础信息\s*$", markdown, re.MULTILINE)
    if not heading:
        raise ValueError("Missing 基础信息 section")

    next_heading = re.search(r"^## .+$", markdown[heading.end():], re.MULTILINE)
    end = heading.end() + next_heading.start() if next_heading else len(markdown)
    section = markdown[heading.end():end]
    table: dict[str, str] = {}

    for line in section.splitlines():
        if not line.startswith("|"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 2:
            continue
        key, value = cells
        if key in {"字段", "---"} or set(key) == {"-"}:
            continue
        table[key] = value

    return table


def validate_keyword_format(locale: str, value: str) -> list[str]:
    errors: list[str] = []
    if ", " in value:
        errors.append(f"{locale}.keywords should not contain spaces after commas")
    if value.startswith(",") or value.endswith(","):
        errors.append(f"{locale}.keywords should not start or end with a comma")
    if ",," in value:
        errors.append(f"{locale}.keywords contains an empty keyword")
    return errors


def validate() -> int:
    markdown = MATERIALS_PATH.read_text(encoding="utf-8")
    errors: list[str] = []

    try:
        basic_info = extract_basic_info(markdown)
    except ValueError as exc:
        errors.append(str(exc))
        basic_info = {}

    for key, expected in BASIC_INFO_EXPECTATIONS.items():
        actual = basic_info.get(key)
        print(f"basic_info.{key}: {actual or '<missing>'}")
        if actual != expected:
            errors.append(f"basic_info.{key} expected {expected!r}; got {actual!r}")

    for locale, config in LOCALIZATIONS.items():
        try:
            section = extract_localized_section(markdown, config["heading"])
        except ValueError as exc:
            errors.append(str(exc))
            continue

        for field in config["fields"]:
            try:
                value = extract_code_block_after_label(section, field.label)
            except ValueError as exc:
                errors.append(f"{locale}.{field.key}: {exc}")
                continue

            char_count = len(value)
            byte_count = len(value.encode("utf-8"))
            print(f"{locale}.{field.key}: chars={char_count} bytes={byte_count}")

            if not value:
                errors.append(f"{locale}.{field.key} is empty")
            if field.char_limit is not None and char_count > field.char_limit:
                errors.append(
                    f"{locale}.{field.key} has {char_count} chars; limit is {field.char_limit}"
                )
            if field.byte_limit is not None and byte_count > field.byte_limit:
                errors.append(
                    f"{locale}.{field.key} has {byte_count} bytes; limit is {field.byte_limit}"
                )
            if field.key == "keywords":
                errors.extend(validate_keyword_format(locale, value))
            for pattern in FORBIDDEN_PATTERNS:
                if pattern.search(value):
                    errors.append(
                        f"{locale}.{field.key} contains forbidden launch copy: {pattern.pattern}"
                    )

    if errors:
        print("\nValidation errors:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nApp Store materials validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(validate())
