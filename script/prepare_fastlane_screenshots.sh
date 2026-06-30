#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${1:-${PEEK_SCREENSHOT_SOURCE_DIR:-/tmp/peek-app-store-screenshots}}"
LOCALES="${PEEK_FASTLANE_SCREENSHOT_LOCALES:-en-US,zh-Hans,ja}"

FILES=(
  "01-hot-corner-panel-2880x1800.png:01_DESKTOP_hot_corner_panel.png"
  "02-quick-search-2880x1800.png:02_DESKTOP_ai_edge.png"
  "03-web-page-2880x1800.png:03_DESKTOP_docs_panel.png"
  "04-tabs-and-pinned-sites-2880x1800.png:04_DESKTOP_metrics_tracker.png"
  "05-pinned-panel-2880x1800.png:05_DESKTOP_pinned_tools.png"
)

fail() {
  printf "prepare_fastlane_screenshots failed: %s\n" "$1" >&2
  exit 1
}

[[ -d "$SOURCE_DIR" ]] || fail "source directory does not exist: $SOURCE_DIR"

for pair in "${FILES[@]}"; do
  source_name="${pair%%:*}"
  [[ -f "$SOURCE_DIR/$source_name" ]] || fail "missing screenshot: $SOURCE_DIR/$source_name"
done

python3 - "$SOURCE_DIR" "${FILES[@]}" <<'PY'
from pathlib import Path
from PIL import Image
import sys

source_dir = Path(sys.argv[1])
for pair in sys.argv[2:]:
    source_name = pair.split(":", 1)[0]
    path = source_dir / source_name
    image = Image.open(path)
    if image.size != (2880, 1800):
        raise SystemExit(f"{path} must be 2880x1800, got {image.size[0]}x{image.size[1]}")
PY

IFS=',' read -r -a locale_array <<<"$LOCALES"
for locale in "${locale_array[@]}"; do
  locale="${locale// /}"
  [[ -n "$locale" ]] || continue
  dest_dir="$ROOT_DIR/fastlane/screenshots/$locale"
  rm -rf "$dest_dir"
  mkdir -p "$dest_dir"
  for pair in "${FILES[@]}"; do
    source_name="${pair%%:*}"
    dest_name="${pair#*:}"
    cp "$SOURCE_DIR/$source_name" "$dest_dir/$dest_name"
  done
  printf "Prepared fastlane screenshots: %s\n" "$dest_dir"
done
