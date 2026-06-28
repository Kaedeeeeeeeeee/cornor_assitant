#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
OUT_DIR="${OUT_DIR:-/tmp/peek-app-store-screenshots}"
LEGACY_APP_STORE_CAPTURE="$OUT_DIR/peek-panel-2880x1800.png"
DEBUG_NOTIFICATION="com.shifeng.peek.debug.panelCommand"
APP_NAME="Corner Peek"
SCREENSHOT_SCENES=(
  "01-hot-corner-panel-2880x1800.png|launcher"
  "02-quick-search-2880x1800.png|search"
  "03-web-page-2880x1800.png|web"
  "04-tabs-and-pinned-sites-2880x1800.png|tabs"
  "05-pinned-panel-2880x1800.png|pinned"
)

log() {
  printf "\n==> %s\n" "$1"
}

fail() {
  printf "capture_app_store_screenshot failed: %s\n" "$1" >&2
  exit 1
}

post_panel_command() {
  local command="$1"
  /usr/bin/swift -e 'import Foundation; let name = Notification.Name(CommandLine.arguments[1]); let command = CommandLine.arguments[2]; DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: ["command": command], deliverImmediately: true); Thread.sleep(forTimeInterval: 0.2)' "$DEBUG_NOTIFICATION" "$command"
}

find_peek_window() {
  /usr/bin/swift - <<'SWIFT'
import CoreGraphics
import Foundation

let displayBounds = CGDisplayBounds(CGMainDisplayID())
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    guard (window[kCGWindowOwnerName as String] as? String) == "Corner Peek",
          let id = window[kCGWindowNumber as String],
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let x = bounds["X"] as? Double,
          let y = bounds["Y"] as? Double,
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          width > 100,
          height > 100 else {
        continue
    }

    print("\(id)\t\(Int(x))\t\(Int(y))\t\(Int(width))\t\(Int(height))\t\(Int(displayBounds.minX))\t\(Int(displayBounds.minY))\t\(Int(displayBounds.width))\t\(Int(displayBounds.height))")
    exit(0)
}

exit(1)
SWIFT
}

crop_window_from_full_capture() {
  local full_capture="$1"
  local raw_capture="$2"
  python3 - "$full_capture" "$raw_capture" "$WINDOW_X" "$WINDOW_Y" "$WINDOW_WIDTH" "$WINDOW_HEIGHT" "$SCREEN_X" "$SCREEN_Y" "$SCREEN_WIDTH" "$SCREEN_HEIGHT" <<'PY'
from pathlib import Path
import sys
from PIL import Image

full_path = Path(sys.argv[1])
raw_path = Path(sys.argv[2])
window_x, window_y, window_w, window_h = map(int, sys.argv[3:7])
screen_x, screen_y, screen_w, screen_h = map(int, sys.argv[7:11])

if not full_path.exists():
    raise SystemExit(f"full capture does not exist: {full_path}")
if screen_w <= 0 or screen_h <= 0:
    raise SystemExit(f"invalid screen bounds: {screen_w}x{screen_h}")

image = Image.open(full_path).convert("RGBA")
scale_x = image.width / screen_w
scale_y = image.height / screen_h

left = round((window_x - screen_x) * scale_x)
top = round((window_y - screen_y) * scale_y)
right = round(left + window_w * scale_x)
bottom = round(top + window_h * scale_y)

left = max(0, min(left, image.width))
right = max(0, min(right, image.width))
top = max(0, min(top, image.height))
bottom = max(0, min(bottom, image.height))

if right - left < 100 or bottom - top < 100:
    raise SystemExit(
        f"cropped window is too small: crop=({left},{top},{right},{bottom}) "
        f"full={image.width}x{image.height}"
    )

image.crop((left, top, right, bottom)).save(raw_path, "PNG")
print(f"full={full_path} full_size={image.width}x{image.height}")
print(f"crop={left},{top},{right},{bottom} raw={raw_path}")
PY
}

validate_and_compose() {
  local raw_capture="$1"
  local app_store_capture="$2"
  python3 - "$raw_capture" "$app_store_capture" <<'PY'
from pathlib import Path
import sys
from PIL import Image, ImageFilter, ImageStat

raw_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])

if not raw_path.exists():
    raise SystemExit(f"raw capture does not exist: {raw_path}")

raw = Image.open(raw_path).convert("RGBA")
width, height = raw.size
if width < 100 or height < 100:
    raise SystemExit(f"raw capture is too small: {width}x{height}")

rgb = raw.convert("RGB")
stat = ImageStat.Stat(rgb)
mean = sum(stat.mean) / 3
max_channel = max(channel_max for _, channel_max in rgb.getextrema())
if mean < 4 or max_channel < 12:
    raise SystemExit("raw capture appears blank or black; grant Screen Recording permission and retry from a visible desktop")

canvas = Image.new("RGB", (2880, 1800), (244, 246, 248))
max_width = 1480
max_height = 1540
scale = min(max_width / width, max_height / height, 1.0)
window = raw.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)

shadow = Image.new("RGBA", (window.width + 96, window.height + 96), (0, 0, 0, 0))
shadow_alpha = Image.new("L", window.size, 105)
shadow.paste((28, 37, 46, 105), (48, 48), shadow_alpha)
shadow = shadow.filter(ImageFilter.GaussianBlur(28))

x = round((canvas.width - window.width) * 0.5)
y = round((canvas.height - window.height) * 0.5)
canvas_rgba = canvas.convert("RGBA")
canvas_rgba.alpha_composite(shadow, (x - 48, y - 48))
canvas_rgba.alpha_composite(window, (x, y))
canvas_rgba.convert("RGB").save(out_path, "PNG")

print(f"raw={raw_path} raw_size={width}x{height}")
print(f"app_store={out_path} app_store_size=2880x1800")
PY
}

capture_scene() {
  local filename="$1"
  local scenario="$2"
  local raw_capture="$OUT_DIR/${filename%.png}-window.png"
  local full_capture="$OUT_DIR/${filename%.png}-full-screen.png"
  local app_store_capture="$OUT_DIR/$filename"

  log "Prepare scene: $scenario"
  post_panel_command "scenario:$scenario"
  sleep 1

  log "Find Corner Peek panel window"
  WINDOW_INFO="$(find_peek_window)" || fail "Corner Peek panel window was not visible"
  IFS=$'\t' read -r WINDOW_ID WINDOW_X WINDOW_Y WINDOW_WIDTH WINDOW_HEIGHT SCREEN_X SCREEN_Y SCREEN_WIDTH SCREEN_HEIGHT <<<"$WINDOW_INFO"
  printf "window id=%s bounds=%s,%s %sx%s screen=%s,%s %sx%s\n" "$WINDOW_ID" "$WINDOW_X" "$WINDOW_Y" "$WINDOW_WIDTH" "$WINDOW_HEIGHT" "$SCREEN_X" "$SCREEN_Y" "$SCREEN_WIDTH" "$SCREEN_HEIGHT"

  log "Capture window: $filename"
  if ! screencapture -x -l "$WINDOW_ID" "$raw_capture"; then
    log "Window capture failed; try full-screen crop fallback"
    if ! screencapture -x "$full_capture"; then
      fail "screencapture could not capture the window or full screen; grant Screen Recording permission to the terminal/Codex host and retry"
    fi
    crop_window_from_full_capture "$full_capture" "$raw_capture"
  fi

  log "Validate and compose 16:10 screenshot: $filename"
  validate_and_compose "$raw_capture" "$app_store_capture"
}

mkdir -p "$OUT_DIR"
trap 'post_panel_command collapse >/dev/null 2>&1 || true' EXIT

log "Launch Debug app"
CONFIGURATION=Debug "$RUN_SCRIPT" --verify

post_panel_command "corner:bottomLeft"

first_capture=""
for scene in "${SCREENSHOT_SCENES[@]}"; do
  IFS='|' read -r filename scenario <<<"$scene"
  capture_scene "$filename" "$scenario"
  if [[ -z "$first_capture" ]]; then
    first_capture="$OUT_DIR/$filename"
  fi
done

cp "$first_capture" "$LEGACY_APP_STORE_CAPTURE"
printf "\nGenerated App Store screenshot suite in %s\n" "$OUT_DIR"
for scene in "${SCREENSHOT_SCENES[@]}"; do
  IFS='|' read -r filename _ <<<"$scene"
  printf "%s\n" "- $filename"
done
printf "%s\n" "- $(basename "$LEGACY_APP_STORE_CAPTURE")"
