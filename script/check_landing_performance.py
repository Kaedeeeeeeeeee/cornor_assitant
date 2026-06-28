#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path


DEFAULT_URL = "https://kaedeeeeeeeeee.github.io/cornor_assitant/"
DEFAULT_OUTPUT_DIR = Path("/tmp/peek-lighthouse")
PAGESPEED_ENDPOINT = "https://www.googleapis.com/pagespeedonline/v5/runPagespeed"
LIGHTHOUSE_CATEGORIES = ["performance", "accessibility", "best-practices", "seo"]
LIGHTHOUSE_THRESHOLDS = {
    "performance": 90,
    "accessibility": 95,
    "best-practices": 95,
    "seo": 95,
}
EXPECTED_AUDITS = [
    "color-contrast",
    "document-title",
    "meta-description",
    "canonical",
    "crawlable-anchors",
]


@dataclass
class CheckResult:
    name: str
    status: str
    detail: str


def env_enabled(name: str, default: bool = False) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip() in {"1", "true", "TRUE", "yes", "YES"}


def add(results: list[CheckResult], name: str, status: str, detail: str) -> None:
    results.append(CheckResult(name=name, status=status, detail=detail))


def find_chrome() -> str | None:
    explicit = os.environ.get("PEEK_CHROME_PATH", "").strip()
    if explicit:
        return explicit

    candidates = [
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return candidate
    return shutil.which("google-chrome") or shutil.which("chromium")


def format_scores(scores: dict[str, int]) -> str:
    return " ".join(f"{category}={scores[category]}" for category in LIGHTHOUSE_CATEGORIES)


def extract_scores(payload: dict[str, object]) -> dict[str, int]:
    categories = payload.get("categories")
    if not isinstance(categories, dict):
        raise ValueError("Lighthouse payload does not contain categories")

    scores: dict[str, int] = {}
    for category in LIGHTHOUSE_CATEGORIES:
        raw_category = categories.get(category)
        if not isinstance(raw_category, dict):
            raise ValueError(f"Lighthouse payload missing category: {category}")
        raw_score = raw_category.get("score")
        if not isinstance(raw_score, (int, float)):
            raise ValueError(f"Lighthouse category has no numeric score: {category}")
        scores[category] = round(float(raw_score) * 100)
    return scores


def scores_below_threshold(scores: dict[str, int]) -> list[str]:
    failures: list[str] = []
    for category, threshold in LIGHTHOUSE_THRESHOLDS.items():
        actual = scores[category]
        if actual < threshold:
            failures.append(f"{category}={actual} below {threshold}")
    return failures


def validate_expected_audits(payload: dict[str, object]) -> list[str]:
    audits = payload.get("audits")
    if not isinstance(audits, dict):
        return ["Lighthouse payload does not contain audits"]

    failures: list[str] = []
    for audit_id in EXPECTED_AUDITS:
        audit = audits.get(audit_id)
        if not isinstance(audit, dict):
            failures.append(f"{audit_id}=missing")
            continue
        score = audit.get("score")
        if score not in (1, True, None):
            failures.append(f"{audit_id}=score {score}")
    return failures


def check_pagespeed(results: list[CheckResult], url: str, strategy: str, timeout: int, fail_on_pagespeed: bool) -> None:
    params = urllib.parse.urlencode(
        {
            "url": url,
            "strategy": strategy,
            "category": LIGHTHOUSE_CATEGORIES,
        },
        doseq=True,
    )
    request = urllib.request.Request(
        f"{PAGESPEED_ENDPOINT}?{params}",
        headers={"User-Agent": "CornerPeekLandingPerformance/1.0"},
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = f"HTTP {exc.code}"
        if exc.reason:
            detail = f"{detail} {exc.reason}"
        add(results, f"pagespeed_{strategy}", "manual", detail)
        return
    except Exception as exc:  # noqa: BLE001 - CLI status probe.
        add(results, f"pagespeed_{strategy}", "manual", str(exc))
        return

    lighthouse_result = payload.get("lighthouseResult")
    if not isinstance(lighthouse_result, dict):
        add(results, f"pagespeed_{strategy}", "manual", "response missing lighthouseResult")
        return

    try:
        scores = extract_scores(lighthouse_result)
    except ValueError as exc:
        add(results, f"pagespeed_{strategy}", "manual", str(exc))
        return

    failures = scores_below_threshold(scores)
    if failures:
        status = "blocked" if fail_on_pagespeed else "manual"
        add(results, f"pagespeed_{strategy}", status, f"{format_scores(scores)}; {'; '.join(failures)}")
    else:
        add(results, f"pagespeed_{strategy}", "ok", format_scores(scores))


def run_lighthouse(results: list[CheckResult], url: str, output_dir: Path, timeout: int) -> None:
    chrome_path = find_chrome()
    npx_path = shutil.which("npx")
    if not chrome_path:
        add(results, "lighthouse_desktop", "blocked", "Chrome/Chromium executable not found")
        return
    if not npx_path:
        add(results, "lighthouse_desktop", "blocked", "npx is not installed")
        return

    output_dir.mkdir(parents=True, exist_ok=True)
    output_path = output_dir / "public-desktop.json"
    command = [
        npx_path,
        "--yes",
        "lighthouse@latest",
        url,
        "--quiet",
        "--preset=desktop",
        f"--chrome-path={chrome_path}",
        "--chrome-flags=--headless=new --disable-gpu --no-first-run",
        "--output=json",
        f"--output-path={output_path}",
        "--only-categories=performance,accessibility,best-practices,seo",
    ]
    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
        timeout=timeout,
        check=False,
    )
    output = "\n".join([result.stdout, result.stderr]).strip()
    if result.returncode != 0:
        add(results, "lighthouse_desktop", "blocked", " | ".join(output.splitlines()[-5:]))
        return

    try:
        payload = json.loads(output_path.read_text(encoding="utf-8"))
        scores = extract_scores(payload)
    except Exception as exc:  # noqa: BLE001 - CLI status probe.
        add(results, "lighthouse_desktop", "blocked", f"could not parse {output_path}: {exc}")
        return

    failures = scores_below_threshold(scores)
    audit_failures = validate_expected_audits(payload)
    details = f"{format_scores(scores)} output={output_path}"
    if failures or audit_failures:
        combined = failures + audit_failures
        add(results, "lighthouse_desktop", "blocked", f"{details}; {'; '.join(combined)}")
    else:
        add(results, "lighthouse_desktop", "ok", details)


def print_results(results: list[CheckResult]) -> None:
    for result in results:
        print(f"{result.status.upper():7} {result.name}: {result.detail}")

    summary: dict[str, int] = {}
    for result in results:
        summary[result.status] = summary.get(result.status, 0) + 1
    print(f"\nsummary: {json.dumps(summary, sort_keys=True)}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Check public Corner Peek landing performance with PageSpeed Insights and local Lighthouse."
    )
    parser.add_argument("--url", default=os.environ.get("PEEK_PERF_URL", DEFAULT_URL), help="Public landing URL")
    parser.add_argument(
        "--output-dir",
        default=os.environ.get("PEEK_LIGHTHOUSE_OUTPUT_DIR", str(DEFAULT_OUTPUT_DIR)),
        help="Directory for Lighthouse JSON output",
    )
    parser.add_argument("--skip-pagespeed", action="store_true", help="Do not call PageSpeed Insights API")
    parser.add_argument("--skip-lighthouse", action="store_true", help="Do not run local Lighthouse")
    parser.add_argument(
        "--fail-on-pagespeed",
        action="store_true",
        default=env_enabled("PEEK_FAIL_ON_PAGESPEED"),
        help="Return non-zero when PageSpeed scores are below thresholds",
    )
    parser.add_argument("--pagespeed-timeout", type=int, default=30, help="PageSpeed request timeout in seconds")
    parser.add_argument("--lighthouse-timeout", type=int, default=240, help="Lighthouse timeout in seconds")
    args = parser.parse_args()

    results: list[CheckResult] = []
    if args.skip_pagespeed and args.skip_lighthouse:
        add(results, "landing_performance", "blocked", "both PageSpeed and Lighthouse checks were skipped")

    if not args.skip_pagespeed:
        for strategy in ["desktop", "mobile"]:
            check_pagespeed(results, args.url, strategy, args.pagespeed_timeout, args.fail_on_pagespeed)

    if not args.skip_lighthouse:
        run_lighthouse(results, args.url, Path(args.output_dir), args.lighthouse_timeout)

    print_results(results)
    return 1 if any(result.status == "blocked" for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
