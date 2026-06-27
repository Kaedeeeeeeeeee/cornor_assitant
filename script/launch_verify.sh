#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/CornerAssistantApp"
PROJECT_PATH="$PROJECT_DIR/CornerAssistantApp.xcodeproj"
SCHEME="CornerAssistantApp"
HOST_ARCH="$(uname -m)"
DESTINATION="${DESTINATION:-platform=macOS,arch=$HOST_ARCH}"
ARCHIVE_PATH="${ARCHIVE_PATH:-/tmp/peek-appstore/Peek.xcarchive}"
APP_PATH="$ARCHIVE_PATH/Products/Applications/Peek.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
PRIVACY_MANIFEST="$APP_PATH/Contents/Resources/PrivacyInfo.xcprivacy"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/Peek"
MATERIALS_VALIDATOR="$ROOT_DIR/script/validate_app_store_materials.py"

log() {
  printf "\n==> %s\n" "$1"
}

fail() {
  printf "launch_verify failed: %s\n" "$1" >&2
  exit 1
}

plist_read() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$2"
}

assert_equals() {
  local label="$1"
  local expected="$2"
  local actual="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail "$label expected '$expected' but got '$actual'"
  fi
}

assert_plist_value() {
  local plist="$1"
  local key="$2"
  local expected="$3"
  local actual
  actual="$(plist_read "$key" "$plist")"
  assert_equals "$key" "$expected" "$actual"
}

log "App Store materials"
"$MATERIALS_VALIDATOR"

log "Release build"
xcodebuild \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  build

log "Unit tests without UI runner"
xcodebuild \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -skip-testing:CornerAssistantAppUITests \
  test

log "Release archive"
rm -rf "$ARCHIVE_PATH"
xcodebuild archive \
  -quiet \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates

[[ -d "$APP_PATH" ]] || fail "archive app not found at $APP_PATH"
[[ -x "$APP_EXECUTABLE" ]] || fail "archive executable not found at $APP_EXECUTABLE"

log "Archive Info.plist"
assert_plist_value "$INFO_PLIST" "CFBundleDisplayName" "Peek"
assert_plist_value "$INFO_PLIST" "CFBundleIdentifier" "com.shifeng.peek"
assert_plist_value "$INFO_PLIST" "CFBundleShortVersionString" "1.0"
assert_plist_value "$INFO_PLIST" "CFBundleVersion" "1"
assert_plist_value "$INFO_PLIST" "LSMinimumSystemVersion" "15.0"
assert_plist_value "$INFO_PLIST" "LSApplicationCategoryType" "public.app-category.productivity"
assert_plist_value "$INFO_PLIST" "NSHumanReadableCopyright" "Copyright 2026 Zhang Shifeng"
assert_plist_value "$INFO_PLIST" "ITSAppUsesNonExemptEncryption" "false"
microphone_usage="$(plist_read "NSMicrophoneUsageDescription" "$INFO_PLIST")"
[[ -n "$microphone_usage" ]] || fail "NSMicrophoneUsageDescription is empty"

log "Archive entitlements"
ENTITLEMENTS_PLIST="$(mktemp "${TMPDIR:-/tmp}/peek-entitlements.XXXXXX.plist")"
trap 'rm -f "$ENTITLEMENTS_PLIST"' EXIT
codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS_PLIST" 2>/dev/null
assert_plist_value "$ENTITLEMENTS_PLIST" "com.apple.security.app-sandbox" "true"
assert_plist_value "$ENTITLEMENTS_PLIST" "com.apple.security.network.client" "true"
assert_plist_value "$ENTITLEMENTS_PLIST" "com.apple.security.device.audio-input" "true"
if /usr/libexec/PlistBuddy -c "Print :com.apple.security.get-task-allow" "$ENTITLEMENTS_PLIST" >/dev/null 2>&1; then
  fail "archive entitlements unexpectedly contain get-task-allow"
fi

log "Privacy manifest"
[[ -f "$PRIVACY_MANIFEST" ]] || fail "PrivacyInfo.xcprivacy missing from archive"
assert_plist_value "$PRIVACY_MANIFEST" "NSPrivacyTracking" "false"
privacy_summary="$(plutil -p "$PRIVACY_MANIFEST")"
grep -q '"NSPrivacyCollectedDataTypes" => \[' <<<"$privacy_summary" || fail "NSPrivacyCollectedDataTypes missing"
grep -q '"NSPrivacyAccessedAPICategoryUserDefaults"' <<<"$privacy_summary" || fail "UserDefaults required-reason API entry missing"
grep -q '"CA92.1"' <<<"$privacy_summary" || fail "UserDefaults CA92.1 reason missing"

log "Release-only debug guard"
if strings "$APP_EXECUTABLE" | grep -q 'com\.shifeng\.peek\.debug\.panelCommand'; then
  fail "Debug-only panel command leaked into Release archive"
fi

if [[ "${SKIP_NETWORK:-0}" != "1" ]]; then
  log "Public landing URLs"
  urls=(
    "https://kaedeeeeeeeeee.github.io/cornor_assitant/"
    "https://kaedeeeeeeeeee.github.io/cornor_assitant/privacy.html"
    "https://kaedeeeeeeeeee.github.io/cornor_assitant/support.html"
    "https://kaedeeeeeeeeee.github.io/cornor_assitant/robots.txt"
    "https://kaedeeeeeeeeee.github.io/cornor_assitant/sitemap.xml"
    "https://kaedeeeeeeeeee.github.io/cornor_assitant/assets/social-preview.png"
    "https://kaedeeeeeeeeee.github.io/cornor_assitant/analytics-config.js"
  )
  for url in "${urls[@]}"; do
    curl -fsSI --max-time 20 "$url" >/dev/null || fail "URL not reachable: $url"
  done
fi

log "Launch verification passed"
