#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHECKLIST_PATH = ROOT / "CornerAssistantApp" / "docs" / "Manual-QA-Checklist.md"

REQUIRED_MARKERS = [
    "# Peek Manual QA Checklist",
    "## 测试前准备",
    "## 必跑交互",
    "### 首次启动",
    "### 菜单栏图标点击",
    "### 菜单栏右键/control-click 菜单",
    "### 热角唤出和自动收起",
    "### 面板尺寸调整",
    "### 搜索、URL 和标签页",
    "### 固定网站",
    "### Launch at Login",
    "### WebKit 常见登录页面",
    "### 无网络环境",
    "## App Store 截图验收",
    "## 上架前人工证据",
    "## 当前已知人工阻塞",
    "macOS 15.0",
    "1.0 (1)",
    "./script/capture_app_store_screenshot.sh",
    "GA4 Measurement ID",
    "Bing Webmaster Tools",
    "Google Search Console sitemap",
]

FORBIDDEN_COPY = [
    re.compile(pattern, re.IGNORECASE)
    for pattern in [
        r"\bTODO\b",
        r"\bTBD\b",
        r"Lorem ipsum",
    ]
]


def main() -> int:
    errors: list[str] = []
    if not CHECKLIST_PATH.exists():
        print(f"Manual QA checklist missing: {CHECKLIST_PATH}", file=sys.stderr)
        return 1

    text = CHECKLIST_PATH.read_text(encoding="utf-8")

    for marker in REQUIRED_MARKERS:
        if marker not in text:
            errors.append(f"missing marker: {marker!r}")

    checkbox_count = text.count("- [ ]")
    print(f"manual_qa.checkbox_count: {checkbox_count}")
    if checkbox_count < 45:
        errors.append(f"expected at least 45 unchecked checklist items, found {checkbox_count}")

    for pattern in FORBIDDEN_COPY:
        match = pattern.search(text)
        if match:
            errors.append(f"contains forbidden or placeholder copy: {match.group(0)!r}")

    if errors:
        print("\nManual QA checklist validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nManual QA checklist validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
