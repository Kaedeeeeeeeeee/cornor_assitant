#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import urllib.request
import plistlib
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_URL = "https://kaedeeeeeeeeee.github.io/cornor_assitant/"
REPO = "Kaedeeeeeeeeee/cornor_assitant"
PAGES_WORKFLOW = "pages.yml"
EXPECTED_PAGES_URL = BASE_URL
EXPECTED_SITEMAP_URLS = {
    BASE_URL,
    f"{BASE_URL}privacy.html",
    f"{BASE_URL}support.html",
}
SEARCH_BOT_USER_AGENTS = {
    "googlebot_sitemap_fetch": "Googlebot/2.1 (+http://www.google.com/bot.html)",
    "bingbot_sitemap_fetch": "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)",
}
ARCHIVE_PATH = Path("/tmp/peek-appstore/Peek.xcarchive")
EXPORT_PATH = Path("/tmp/peek-appstore/external-readiness-export")
EXPORT_OPTIONS = ROOT / "CornerAssistantApp" / "export_options_app_store.plist"
SCREENSHOT_OUTPUT_DIR = Path("/tmp/peek-app-store-screenshots")
EXPECTED_SCREENSHOTS = [
    "01-hot-corner-panel-2880x1800.png",
    "02-quick-search-2880x1800.png",
    "03-web-page-2880x1800.png",
    "04-tabs-and-pinned-sites-2880x1800.png",
    "05-pinned-panel-2880x1800.png",
]


@dataclass
class CheckResult:
    name: str
    status: str
    detail: str


class MetaParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.meta: dict[str, str] = {}

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag.lower() != "meta":
            return
        attrs_dict = {key.lower(): value or "" for key, value in attrs}
        name = attrs_dict.get("name")
        content = attrs_dict.get("content", "")
        if name:
            self.meta[name.lower()] = content


def env_enabled(name: str) -> bool:
    return os.environ.get(name, "").strip() in {"1", "true", "TRUE", "yes", "YES"}


def run(command: list[str], timeout: int = 30) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )


def read_plist(path: Path) -> dict[str, object]:
    with path.open("rb") as file:
        value = plistlib.load(file)
    if not isinstance(value, dict):
        raise ValueError(f"plist root is not a dictionary: {path}")
    return value


def exported_app_path(export_path: Path) -> Path:
    apps = sorted(path for path in export_path.rglob("*.app") if path.is_dir())
    if len(apps) != 1:
        raise ValueError(f"expected one exported .app in {export_path}, found {len(apps)}")
    return apps[0]


def validate_exported_app(export_path: Path) -> str:
    app_path = exported_app_path(export_path)
    info_plist = app_path / "Contents" / "Info.plist"
    privacy_manifest = app_path / "Contents" / "Resources" / "PrivacyInfo.xcprivacy"
    executable = app_path / "Contents" / "MacOS" / "Peek"

    if not info_plist.exists():
        raise ValueError(f"exported app Info.plist missing: {info_plist}")
    if not privacy_manifest.exists():
        raise ValueError(f"exported app PrivacyInfo.xcprivacy missing: {privacy_manifest}")
    if not executable.exists():
        raise ValueError(f"exported app executable missing: {executable}")

    info = read_plist(info_plist)
    expected_info = {
        "CFBundleIdentifier": "com.shifeng.peek",
        "CFBundleShortVersionString": "1.0",
        "CFBundleVersion": "1",
        "LSMinimumSystemVersion": "15.0",
        "LSApplicationCategoryType": "public.app-category.productivity",
    }
    for key, expected in expected_info.items():
        actual = info.get(key)
        if actual != expected:
            raise ValueError(f"exported app {key} expected {expected!r}, got {actual!r}")

    entitlements = run(["codesign", "-d", "--entitlements", ":-", str(app_path)], timeout=30)
    entitlements_xml = "\n".join([entitlements.stdout, entitlements.stderr])
    if entitlements.returncode != 0:
        raise ValueError(f"could not read exported app entitlements: {' | '.join(entitlements_xml.splitlines()[-5:])}")

    if "com.apple.security.get-task-allow" in entitlements_xml:
        raise ValueError("exported app entitlements contain com.apple.security.get-task-allow")
    for required in [
        "com.apple.security.app-sandbox",
        "com.apple.security.network.client",
        "com.apple.security.device.audio-input",
    ]:
        if required not in entitlements_xml:
            raise ValueError(f"exported app entitlements missing {required}")

    return str(app_path)


def fetch_text(url: str, user_agent: str = "PeekExternalReadiness/1.0") -> tuple[int, str]:
    request = urllib.request.Request(url, headers={"User-Agent": user_agent})
    with urllib.request.urlopen(request, timeout=20) as response:
        status = getattr(response, "status", 200)
        body = response.read().decode("utf-8")
        return status, body


def add(results: list[CheckResult], name: str, status: str, detail: str) -> None:
    results.append(CheckResult(name=name, status=status, detail=detail))


def check_public_landing(results: list[CheckResult]) -> None:
    urls = [
        BASE_URL,
        f"{BASE_URL}privacy.html",
        f"{BASE_URL}support.html",
        f"{BASE_URL}robots.txt",
        f"{BASE_URL}sitemap.xml",
        f"{BASE_URL}analytics-config.js",
    ]
    for url in urls:
        try:
            status, _ = fetch_text(url)
        except Exception as exc:  # noqa: BLE001 - CLI status probe.
            add(results, f"public_url:{url}", "blocked", str(exc))
            continue
        add(results, f"public_url:{url}", "ok", f"HTTP {status}")


def sitemap_locations(xml_body: str) -> set[str]:
    root = ET.fromstring(xml_body)
    namespace = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
    return {loc.text for loc in root.findall(".//sm:loc", namespace) if loc.text}


def check_search_bot_sitemap_fetch(results: list[CheckResult]) -> None:
    sitemap_url = f"{BASE_URL}sitemap.xml"
    for check_name, user_agent in SEARCH_BOT_USER_AGENTS.items():
        try:
            status, body = fetch_text(sitemap_url, user_agent=user_agent)
            locations = sitemap_locations(body)
        except Exception as exc:  # noqa: BLE001 - CLI status probe.
            add(results, check_name, "blocked", str(exc))
            continue

        missing = EXPECTED_SITEMAP_URLS - locations
        if status == 200 and not missing:
            add(results, check_name, "ok", f"HTTP 200; {len(locations)} sitemap URLs")
        elif missing:
            add(results, check_name, "blocked", f"sitemap missing URLs: {', '.join(sorted(missing))}")
        else:
            add(results, check_name, "blocked", f"HTTP {status}")


def check_analytics_config(results: list[CheckResult]) -> None:
    try:
        _, body = fetch_text(f"{BASE_URL}analytics-config.js")
    except Exception as exc:  # noqa: BLE001 - CLI status probe.
        add(results, "landing_analytics_config", "blocked", str(exc))
        return

    config = body.strip()
    prefix = 'window.PEEK_GA_MEASUREMENT_ID = "'
    suffix = '";'
    if not (config.startswith(prefix) and config.endswith(suffix)):
        add(results, "landing_analytics_config", "blocked", f"unexpected format: {config}")
        return

    measurement_id = config[len(prefix):-len(suffix)]
    if measurement_id:
        add(results, "landing_analytics_config", "ok", f"GA4 id is configured: {measurement_id}")
    else:
        add(results, "landing_analytics_config", "manual", "GA4 id is empty; public site does not load GA")


def check_site_verification_meta(results: list[CheckResult]) -> None:
    try:
        _, body = fetch_text(BASE_URL)
    except Exception as exc:  # noqa: BLE001 - CLI status probe.
        add(results, "google_site_verification", "blocked", str(exc))
        add(results, "bing_site_verification", "blocked", str(exc))
        return

    parser = MetaParser()
    parser.feed(body)
    google_token = parser.meta.get("google-site-verification", "").strip()
    bing_token = parser.meta.get("msvalidate.01", "").strip()

    if google_token:
        add(results, "google_site_verification", "ok", "google-site-verification meta is present")
    else:
        add(
            results,
            "google_site_verification",
            "manual",
            "google-site-verification meta is absent; set PEEK_GOOGLE_SITE_VERIFICATION",
        )

    if bing_token:
        add(results, "bing_site_verification", "ok", "msvalidate.01 meta is present")
    else:
        add(
            results,
            "bing_site_verification",
            "manual",
            "msvalidate.01 meta is absent; set PEEK_BING_SITE_VERIFICATION",
        )


def check_github(results: list[CheckResult]) -> None:
    if not shutil.which("gh"):
        add(results, "github_cli", "manual", "gh is not installed")
        return

    auth = run(["gh", "auth", "status"], timeout=30)
    if auth.returncode != 0:
        add(results, "github_cli", "manual", "gh is not authenticated")
        return
    add(results, "github_cli", "ok", "gh auth status succeeded")

    pages = run(["gh", "api", f"repos/{REPO}/pages"], timeout=30)
    if pages.returncode != 0:
        add(results, "github_pages", "blocked", pages.stderr.strip() or pages.stdout.strip())
    else:
        data = json.loads(pages.stdout)
        html_url = data.get("html_url")
        build_type = data.get("build_type")
        cname = data.get("cname")
        if html_url == EXPECTED_PAGES_URL and build_type == "workflow" and cname is None:
            add(results, "github_pages", "ok", f"workflow pages at {html_url}")
        else:
            add(results, "github_pages", "blocked", json.dumps(data, ensure_ascii=False))

    runs = run(
        [
            "gh",
            "run",
            "list",
            "--repo",
            REPO,
            "--workflow",
            PAGES_WORKFLOW,
            "--limit",
            "1",
            "--json",
            "status,conclusion,databaseId,displayTitle,headSha,updatedAt,url",
        ],
        timeout=30,
    )
    if runs.returncode != 0:
        add(results, "github_pages_workflow", "blocked", runs.stderr.strip() or runs.stdout.strip())
    else:
        latest = json.loads(runs.stdout)
        if latest and latest[0].get("status") == "completed" and latest[0].get("conclusion") == "success":
            run_info = latest[0]
            head_sha = str(run_info.get("headSha") or "")
            stale_status = pages_stale_status(head_sha)
            if stale_status:
                status, detail = stale_status
                add(results, "github_pages_workflow", status, detail)
            else:
                add(
                    results,
                    "github_pages_workflow",
                    "ok",
                    f"latest run {run_info.get('databaseId')} succeeded at {run_info.get('updatedAt')}",
                )
        else:
            add(results, "github_pages_workflow", "blocked", json.dumps(latest, ensure_ascii=False))

    variables = run(["gh", "api", f"repos/{REPO}/actions/variables"], timeout=30)
    if variables.returncode != 0:
        add(results, "github_actions_variables", "blocked", variables.stderr.strip() or variables.stdout.strip())
    else:
        data = json.loads(variables.stdout)
        names = {item.get("name") for item in data.get("variables", [])}
        expected_variables = {
            "PEEK_GA_MEASUREMENT_ID",
            "PEEK_GOOGLE_SITE_VERIFICATION",
            "PEEK_BING_SITE_VERIFICATION",
        }
        missing = sorted(expected_variables - names)
        if not missing:
            add(results, "github_actions_variables", "ok", "landing config variables exist")
        else:
            add(results, "github_actions_variables", "manual", f"missing variables: {', '.join(missing)}")


def pages_stale_status(pages_head_sha: str) -> tuple[str, str] | None:
    if not pages_head_sha:
        return "manual", "latest Pages run did not report a head SHA"

    local_head = run(["git", "rev-parse", "HEAD"], timeout=30)
    if local_head.returncode != 0:
        return "manual", "could not read local git HEAD"

    current_head = local_head.stdout.strip()
    if pages_head_sha == current_head:
        return None

    diff = run(
        [
            "git",
            "diff",
            "--name-only",
            f"{pages_head_sha}..HEAD",
            "--",
            "CornerAssistantApp/landing-page",
            ".github/workflows/pages.yml",
        ],
        timeout=30,
    )
    if diff.returncode != 0:
        return "manual", "could not compare latest Pages run with local HEAD"

    deploy_affecting_changes = [line.strip() for line in diff.stdout.splitlines() if line.strip()]
    if deploy_affecting_changes:
        preview = ", ".join(deploy_affecting_changes[:5])
        if len(deploy_affecting_changes) > 5:
            preview += ", ..."
        return "blocked", f"latest successful Pages run is stale for deploy-affecting changes: {preview}"

    return "ok", "latest Pages run succeeded; no landing/page workflow changes since that run"


def check_app_store_export(results: list[CheckResult]) -> None:
    if not env_enabled("PEEK_CHECK_EXPORT"):
        add(results, "app_store_export", "skipped", "set PEEK_CHECK_EXPORT=1 to run xcodebuild -exportArchive")
        return
    if not ARCHIVE_PATH.exists():
        add(results, "app_store_export", "blocked", f"archive missing: {ARCHIVE_PATH}")
        return

    command = [
        "xcodebuild",
        "-exportArchive",
        "-archivePath",
        str(ARCHIVE_PATH),
        "-exportPath",
        str(EXPORT_PATH),
        "-exportOptionsPlist",
        str(EXPORT_OPTIONS),
    ]
    if env_enabled("PEEK_ALLOW_PROVISIONING_UPDATES"):
        command.append("-allowProvisioningUpdates")
    result = run(command, timeout=120)
    output = "\n".join([result.stdout, result.stderr]).strip()
    if result.returncode == 0:
        try:
            app_path = validate_exported_app(EXPORT_PATH)
        except Exception as exc:  # noqa: BLE001 - report validation failure in readiness summary.
            add(results, "app_store_export", "blocked", f"export succeeded but validation failed: {exc}")
        else:
            add(results, "app_store_export", "ok", f"export succeeded and validated: {app_path}")
    elif "No Accounts" in output or "No profiles for 'com.shifeng.peek'" in output:
        add(results, "app_store_export", "blocked", "No Accounts / no com.shifeng.peek App Store profile")
    else:
        add(results, "app_store_export", "blocked", " | ".join(output.splitlines()[-5:]))


def check_screenshot_capture(results: list[CheckResult]) -> None:
    if not env_enabled("PEEK_CHECK_SCREENSHOT"):
        add(results, "app_store_screenshot_capture", "skipped", "set PEEK_CHECK_SCREENSHOT=1 to run screenshot capture")
        return
    result = run([str(ROOT / "script" / "capture_app_store_screenshot.sh")], timeout=120)
    output = "\n".join([result.stdout, result.stderr]).strip()
    if result.returncode == 0:
        try:
            from PIL import Image
        except ImportError:
            add(results, "app_store_screenshot_capture", "blocked", "Pillow is missing; cannot validate screenshot dimensions")
            return

        missing: list[str] = []
        invalid: list[str] = []
        for filename in EXPECTED_SCREENSHOTS:
            path = SCREENSHOT_OUTPUT_DIR / filename
            if not path.exists():
                missing.append(filename)
                continue
            with Image.open(path) as image:
                if image.size != (2880, 1800):
                    invalid.append(f"{filename}: {image.size[0]}x{image.size[1]}")

        if missing or invalid:
            details = []
            if missing:
                details.append(f"missing: {', '.join(missing)}")
            if invalid:
                details.append(f"invalid sizes: {', '.join(invalid)}")
            add(results, "app_store_screenshot_capture", "blocked", " | ".join(details))
        else:
            add(results, "app_store_screenshot_capture", "ok", "5 screenshot files generated at 2880x1800")
    elif (
        "Screen Recording" in output
        or "could not create image from window" in output
        or "blank or black" in output
    ):
        add(results, "app_store_screenshot_capture", "blocked", "Screen Recording/window capture permission is not usable")
    else:
        add(results, "app_store_screenshot_capture", "blocked", " | ".join(output.splitlines()[-5:]))


def check_local_qa_smoke(results: list[CheckResult]) -> None:
    if not env_enabled("PEEK_CHECK_QA_SMOKE"):
        add(results, "local_qa_smoke", "skipped", "set PEEK_CHECK_QA_SMOKE=1 to run menu bar and panel smoke QA")
        return

    result = run([str(ROOT / "script" / "qa_smoke.sh")], timeout=120)
    output = "\n".join([result.stdout, result.stderr]).strip()
    if result.returncode == 0 and "qa_smoke passed" in output:
        add(results, "local_qa_smoke", "ok", "menu bar status item and four-corner panel smoke QA passed")
    elif "Accessibility UI scripting is disabled" in output:
        add(results, "local_qa_smoke", "blocked", "Accessibility UI scripting is disabled")
    else:
        add(results, "local_qa_smoke", "blocked", " | ".join(output.splitlines()[-5:]))


def print_results(results: list[CheckResult]) -> None:
    for result in results:
        print(f"{result.status.upper():7} {result.name}: {result.detail}")

    summary: dict[str, int] = {}
    for result in results:
        summary[result.status] = summary.get(result.status, 0) + 1
    print(f"\nsummary: {json.dumps(summary, sort_keys=True)}")


def main() -> int:
    results: list[CheckResult] = []
    check_public_landing(results)
    check_search_bot_sitemap_fetch(results)
    check_analytics_config(results)
    check_site_verification_meta(results)
    check_github(results)
    check_app_store_export(results)
    check_screenshot_capture(results)
    check_local_qa_smoke(results)
    print_results(results)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
