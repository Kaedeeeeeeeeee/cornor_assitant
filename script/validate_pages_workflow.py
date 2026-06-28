#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOW_PATH = ROOT / ".github" / "workflows" / "pages.yml"


REQUIRED_SNIPPETS = {
    "workflow name": "name: Deploy Corner Peek landing page",
    "push trigger": "push:",
    "main branch trigger": "- main",
    "landing path trigger": '- "CornerAssistantApp/landing-page/**"',
    "workflow path trigger": '- ".github/workflows/pages.yml"',
    "manual dispatch trigger": "workflow_dispatch:",
    "contents permission": "contents: read",
    "pages permission": "pages: write",
    "id-token permission": "id-token: write",
    "pages environment": "name: github-pages",
    "ubuntu runner": "runs-on: ubuntu-latest",
    "checkout action": "uses: actions/checkout@v4",
    "configure pages action": "uses: actions/configure-pages@v5",
    "upload pages artifact action": "uses: actions/upload-pages-artifact@v3",
    "deploy pages action": "uses: actions/deploy-pages@v4",
    "artifact path": "path: CornerAssistantApp/landing-page",
    "analytics variable": "PEEK_GA_MEASUREMENT_ID: ${{ vars.PEEK_GA_MEASUREMENT_ID }}",
    "google verification variable": "PEEK_GOOGLE_SITE_VERIFICATION: ${{ vars.PEEK_GOOGLE_SITE_VERIFICATION }}",
    "bing verification variable": "PEEK_BING_SITE_VERIFICATION: ${{ vars.PEEK_BING_SITE_VERIFICATION }}",
    "analytics output file": 'fs.writeFileSync("CornerAssistantApp/landing-page/analytics-config.js", body);',
    "site verification output file": 'fs.writeFileSync(indexPath, nextHtml);',
    "site verification head insertion": 'html.replace("</head>",',
}

REQUIRED_REGEXES = {
    "GA4 id guard": re.compile(r"\^G-\[A-Z0-9\]\+\$"),
    "empty invalid GA4 fallback": re.compile(r"\?\s+id\s+:\s+\"\""),
    "site verification token guard": re.compile(r"\^\[A-Za-z0-9_-\]\+\$"),
    "html attribute amp escape": re.compile(r"\.replace\(/&/g,\s*\"&amp;\"\)"),
    "html attribute quote escape": re.compile(r"\.replace\(/\"/g,\s*\"&quot;\"\)"),
    "html attribute less-than escape": re.compile(r"\.replace\(/</g,\s*\"&lt;\"\)"),
    "html attribute greater-than escape": re.compile(r"\.replace\(/>/g,\s*\"&gt;\"\)"),
    "empty site token no-op": re.compile(r"No site verification tokens configured\."),
    "missing head guard": re.compile(r"index\.html is missing </head>"),
}

FORBIDDEN_SNIPPETS = {
    "analytics secret reference": "secrets.PEEK_GA_MEASUREMENT_ID",
    "google verification secret reference": "secrets.PEEK_GOOGLE_SITE_VERIFICATION",
    "bing verification secret reference": "secrets.PEEK_BING_SITE_VERIFICATION",
    "hard-coded GA4 id": "G-XXXXXXXXXX",
    "legacy GitHub Pages action": "actions/deploy-pages@v3",
}


def main() -> int:
    errors: list[str] = []
    if not WORKFLOW_PATH.exists():
        print(f"GitHub Pages workflow validation failed:\n- missing {WORKFLOW_PATH}", file=sys.stderr)
        return 1

    workflow = WORKFLOW_PATH.read_text(encoding="utf-8")

    for label, snippet in REQUIRED_SNIPPETS.items():
        print(f"pages_workflow.{label}: {'ok' if snippet in workflow else 'missing'}")
        if snippet not in workflow:
            errors.append(f"missing {label}: {snippet}")

    for label, pattern in REQUIRED_REGEXES.items():
        matched = bool(pattern.search(workflow))
        print(f"pages_workflow.{label}: {'ok' if matched else 'missing'}")
        if not matched:
            errors.append(f"missing {label}: {pattern.pattern}")

    for label, snippet in FORBIDDEN_SNIPPETS.items():
        if snippet in workflow:
            errors.append(f"forbidden {label}: {snippet}")

    if workflow.count("actions/deploy-pages@") != 1:
        errors.append("workflow should contain exactly one deploy-pages action")
    if workflow.count("CornerAssistantApp/landing-page") < 2:
        errors.append("workflow should reference the landing-page directory in trigger and artifact path")

    if errors:
        print("\nGitHub Pages workflow validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nGitHub Pages workflow validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
