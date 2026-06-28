#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
import urllib.request
from dataclasses import dataclass
from urllib.parse import urlparse

from validate_app_store_materials import MATERIALS_PATH, extract_basic_info


EXPECTED_URLS = {
    "Marketing URL": "https://kaedeeeeeeeeee.github.io/cornor_assitant/",
    "Privacy Policy URL": "https://kaedeeeeeeeeee.github.io/cornor_assitant/privacy.html",
    "Support URL": "https://kaedeeeeeeeeee.github.io/cornor_assitant/support.html",
}


@dataclass(frozen=True)
class URLCheck:
    field: str
    url: str


def strip_inline_code(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`"):
        return value[1:-1]
    return value


def validate_https_public_url(check: URLCheck, errors: list[str]) -> None:
    parsed = urlparse(check.url)
    print(f"app_store_url.{check.field}: {check.url}")

    if parsed.scheme != "https":
        errors.append(f"{check.field} must use https: {check.url}")
    if parsed.hostname != "kaedeeeeeeeeee.github.io":
        errors.append(f"{check.field} must use the production GitHub Pages host: {check.url}")
    if parsed.username or parsed.password:
        errors.append(f"{check.field} must not include credentials: {check.url}")
    if parsed.fragment:
        errors.append(f"{check.field} must not include a URL fragment: {check.url}")


def validate_network(check: URLCheck, errors: list[str]) -> None:
    request = urllib.request.Request(
        check.url,
        headers={"User-Agent": "CornerPeekAppStoreURLVerifier/1.0"},
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            status = getattr(response, "status", 200)
            print(f"app_store_url.{check.field}.status: HTTP {status}")
            if status != 200:
                errors.append(f"{check.field} returned HTTP {status}: {check.url}")
    except Exception as exc:  # noqa: BLE001 - CLI verifier should report URL failures.
        errors.append(f"{check.field} is not reachable: {exc}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate App Store Connect public URLs for Corner Peek.")
    parser.add_argument(
        "--check-network",
        action="store_true",
        help="Fetch each App Store URL and require HTTP 200.",
    )
    args = parser.parse_args()

    markdown = MATERIALS_PATH.read_text(encoding="utf-8")
    basic_info = extract_basic_info(markdown)
    errors: list[str] = []
    checks: list[URLCheck] = []

    for field, expected in EXPECTED_URLS.items():
        actual = strip_inline_code(basic_info.get(field, ""))
        if actual != expected:
            errors.append(f"{field} expected {expected!r}; got {actual!r}")
        checks.append(URLCheck(field=field, url=actual))

    for check in checks:
        validate_https_public_url(check, errors)
        if args.check_network:
            validate_network(check, errors)

    if errors:
        print("\nApp Store URL validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nApp Store URL validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
