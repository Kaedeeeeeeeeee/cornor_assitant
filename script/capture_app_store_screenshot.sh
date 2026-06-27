#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
OUT_DIR="${OUT_DIR:-/tmp/peek-app-store-screenshots}"
RAW_CAPTURE="$OUT_DIR/peek-panel-window.png"
APP_STORE_CAPTURE="$OUT_DIR/peek-panel-2880x1800.png"
DEBUG_NOTIFICATION="com.shifeng.peek.debug.panelCommand"

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

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for window in windows {
    guard (window[kCGWindowOwnerName as String] as? String) == "Peek",
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

    print("\(id)\t\(Int(x))\t\(Int(y))\t\(Int(width))\t\(Int(height))")
    exit(0)
}

exit(1)
SWIFT
}

validate_and_compose() {
  python3 - "$RAW_CAPTURE" "$APP_STORE_CAPTURE" <<'PY'
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

mkdir -p "$OUT_DIR"
trap 'post_panel_command collapse >/dev/null 2>&1 || true' EXIT

log "Launch Debug app"
CONFIGURATION=Debug "$RUN_SCRIPT" --verify

log "Expand panel"
post_panel_command expand
sleep 1

log "Find Peek panel window"
WINDOW_INFO="$(find_peek_window)" || fail "Peek panel window was not visible"
IFS=$'\t' read -r WINDOW_ID WINDOW_X WINDOW_Y WINDOW_WIDTH WINDOW_HEIGHT <<<"$WINDOW_INFO"
printf "window id=%s bounds=%s,%s %sx%s\n" "$WINDOW_ID" "$WINDOW_X" "$WINDOW_Y" "$WINDOW_WIDTH" "$WINDOW_HEIGHT"

log "Capture window"
if ! screencapture -x -l "$WINDOW_ID" "$RAW_CAPTURE"; then
  fail "screencapture could not capture Peek window; grant Screen Recording permission to the terminal/Codex host and retry"
fi

log "Validate and compose 16:10 screenshot"
validate_and_compose
