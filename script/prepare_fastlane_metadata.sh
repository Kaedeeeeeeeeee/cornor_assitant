#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/peek-fastlane-metadata.XXXXXX")"
DEST_DIR="$ROOT_DIR/fastlane/metadata"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

OUT_DIR="$TMP_DIR" "$ROOT_DIR/script/export_app_store_metadata.py" >/dev/null

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

for locale_dir in "$TMP_DIR"/metadata/*; do
  [[ -d "$locale_dir" ]] || continue
  locale="$(basename "$locale_dir")"
  dest_locale="$DEST_DIR/$locale"
  mkdir -p "$dest_locale"
  cp "$locale_dir/app_name.txt" "$dest_locale/name.txt"
  cp "$locale_dir/subtitle.txt" "$dest_locale/subtitle.txt"
  cp "$locale_dir/description.txt" "$dest_locale/description.txt"
  cp "$locale_dir/keywords.txt" "$dest_locale/keywords.txt"
  cp "$locale_dir/whats_new.txt" "$dest_locale/release_notes.txt"
done

printf "Prepared fastlane metadata: %s\n" "$DEST_DIR"
