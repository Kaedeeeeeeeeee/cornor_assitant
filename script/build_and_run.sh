#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="Peek"
SCHEME="CornerAssistantApp"
PROJECT_RELATIVE_PATH="CornerAssistantApp/CornerAssistantApp.xcodeproj"
CONFIGURATION="${CONFIGURATION:-Debug}"
HOST_ARCH="$(uname -m)"
DESTINATION="${DESTINATION:-platform=macOS,arch=$HOST_ARCH}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/$PROJECT_RELATIVE_PATH"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/DerivedData/PeekRun}"
APP_BUNDLE="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_EXECUTABLE="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
}

build_app() {
  local args=(
    -project "$PROJECT_PATH"
    -scheme "$SCHEME"
    -configuration "$CONFIGURATION"
    -destination "$DESTINATION"
    -derivedDataPath "$DERIVED_DATA_PATH"
    build
  )

  if [[ "${PEEK_XCODEBUILD_VERBOSE:-0}" == "1" ]]; then
    xcodebuild "${args[@]}"
  else
    xcodebuild -quiet "${args[@]}"
  fi
}

stop_existing() {
  if [[ "${PEEK_SKIP_KILL:-0}" == "1" ]]; then
    return
  fi

  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

stop_existing
build_app

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_EXECUTABLE"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"com.shifeng.peek\" OR process == \"$APP_NAME\""
    ;;
  --verify|verify)
    open_app
    sleep 3
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    usage
    exit 2
    ;;
esac
