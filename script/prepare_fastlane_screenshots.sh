#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${1:-${PEEK_SCREENSHOT_SOURCE_DIR:-$ROOT_DIR/screenshots/store}}"
LOCALES="${PEEK_FASTLANE_SCREENSHOT_LOCALES:-en-US,zh-Hans,ja}"

FILES=(
  "01_edge_hidden_2880x1800.png:01_DESKTOP_edge_hidden.png"
  "02_multi_webapps_2880x1800.png:02_DESKTOP_multi_webapps.png"
  "03_resizable_2880x1800.png:03_DESKTOP_resizable.png"
  "04_quick_search_2880x1800.png:04_DESKTOP_quick_search.png"
  "05_pinned_sites_2880x1800.png:05_DESKTOP_pinned_sites.png"
)

fail() {
  printf "prepare_fastlane_screenshots failed: %s\n" "$1" >&2
  exit 1
}

[[ -d "$SOURCE_DIR" ]] || fail "source directory does not exist: $SOURCE_DIR"

python3 - "$SOURCE_DIR" "$LOCALES" "${FILES[@]}" <<'PY'
from pathlib import Path
from PIL import Image
import sys

source_dir = Path(sys.argv[1])
locales = [locale.strip() for locale in sys.argv[2].split(",") if locale.strip()]
pairs = sys.argv[3:]
for locale in locales:
    locale_dir = source_dir / locale
    if not locale_dir.is_dir():
        raise SystemExit(f"missing locale screenshot directory: {locale_dir}")
    for pair in pairs:
        source_name = pair.split(":", 1)[0]
        path = locale_dir / source_name
        if not path.is_file():
            raise SystemExit(f"missing screenshot: {path}")
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
    cp "$SOURCE_DIR/$locale/$source_name" "$dest_dir/$dest_name"
  done
  printf "Prepared fastlane screenshots: %s\n" "$dest_dir"
done
