#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED_GITIGNORE_LINES = {
    "/build/",
    "/dist/",
    "*.dmg",
    "*.xcarchive/",
    "CornerAssistantApp/build/",
    "CornerAssistantApp/*.log",
}


def git_ls_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return [line for line in result.stdout.splitlines() if line]


def is_generated_artifact(path: str) -> bool:
    return (
        path.startswith("build/")
        or path.startswith("dist/")
        or path.startswith("CornerAssistantApp/build/")
        or "/.build/" in path
        or ".xcarchive/" in path
        or path.endswith(".xcarchive")
        or path.endswith(".dmg")
        or path in {"CornerAssistantApp/build.log", "CornerAssistantApp/build_full.log"}
    )


def main() -> int:
    errors: list[str] = []
    tracked_artifacts = [path for path in git_ls_files() if is_generated_artifact(path)]
    print(f"repository_hygiene.tracked_generated_artifacts: {len(tracked_artifacts)}")
    if tracked_artifacts:
        preview = "\n".join(f"  - {path}" for path in tracked_artifacts[:40])
        errors.append(f"generated artifacts are tracked by git:\n{preview}")

    gitignore_path = ROOT / ".gitignore"
    gitignore_lines = set(gitignore_path.read_text(encoding="utf-8").splitlines())
    for line in sorted(REQUIRED_GITIGNORE_LINES):
        present = line in gitignore_lines
        print(f"repository_hygiene.gitignore.{line}: {'ok' if present else 'missing'}")
        if not present:
            errors.append(f".gitignore missing {line!r}")

    if errors:
        print("\nRepository hygiene validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("\nRepository hygiene validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
