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
  "02-quick-search-2880x1800.png|web"
  "03-web-page-2880x1800.png|tabs"
  "04-tabs-and-pinned-sites-2880x1800.png|sheet"
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
  local scenario="$3"
  python3 - "$raw_capture" "$app_store_capture" "$scenario" <<'PY'
from pathlib import Path
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageStat

raw_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
scenario = sys.argv[3]

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

SCENES = {
    "launcher": {
        "eyebrow": "Pinned tools",
        "headline": "Your web tools, one gesture away.",
        "body": "Move to the hot corner and open daily sites from the screen edge.",
    },
    "web": {
        "eyebrow": "AI at the edge",
        "headline": "AI, one gesture away.",
        "body": "Ask, summarize, or rewrite while your main window stays in place.",
    },
    "tabs": {
        "eyebrow": "Docs and messages",
        "headline": "Check docs without switching.",
        "body": "Keep briefs, notes, and short updates beside your current work.",
    },
    "sheet": {
        "eyebrow": "Trackers and sheets",
        "headline": "Sheets stay out of the way.",
        "body": "Look up trackers and dashboards without opening another full browser.",
    },
    "pinned": {
        "eyebrow": "Your web workflow",
        "headline": "Pin the sites you use daily.",
        "body": "AI, docs, chat, sheets, and dashboards stay ready on the side rail.",
    },
}

FONT_CANDIDATES = [
    "/System/Library/Fonts/SFNS.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/Library/Fonts/Arial.ttf",
]

def load_font(size: int, bold: bool = False):
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "",
        *FONT_CANDIDATES,
    ]
    for path in candidates:
        if not path:
            continue
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()

def rounded_rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, fill, outline=None, width: int = 1) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)

def text_size(draw: ImageDraw.ImageDraw, text: str, font) -> tuple[int, int]:
    box = draw.textbbox((0, 0), text, font=font)
    return box[2] - box[0], box[3] - box[1]

def wrap_text(draw: ImageDraw.ImageDraw, text: str, font, max_width: int) -> list[str]:
    lines: list[str] = []
    for paragraph in text.split("\n"):
        current = ""
        for word in paragraph.split(" "):
            candidate = word if not current else f"{current} {word}"
            if text_size(draw, candidate, font)[0] <= max_width:
                current = candidate
                continue
            if current:
                lines.append(current)
            current = word
        if current:
            lines.append(current)
    return lines

def draw_wrapped(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, font, fill, max_width: int, line_gap: int) -> int:
    x, y = xy
    for line in wrap_text(draw, text, font, max_width):
        draw.text((x, y), line, font=font, fill=fill)
        y += text_size(draw, line, font)[1] + line_gap
    return y

scene = SCENES.get(scenario, SCENES["launcher"])

canvas = Image.new("RGB", (2880, 1800), (255, 255, 255))
canvas_rgba = canvas.convert("RGBA")
draw = ImageDraw.Draw(canvas_rgba)

blue = (37, 99, 235, 255)
blue_soft = (219, 234, 254, 255)
ink = (18, 25, 38, 255)
muted = (93, 105, 123, 255)

draw.rectangle((0, 0, 2880, 1800), fill=(255, 255, 255, 255))

eyebrow_font = load_font(34, bold=True)
headline_font = load_font(102, bold=True)
body_font = load_font(42)

text_x = 300
text_w = 830
headline_lines = wrap_text(draw, scene["headline"], headline_font, text_w)
body_lines = wrap_text(draw, scene["body"], body_font, 760)
headline_h = sum(text_size(draw, line, headline_font)[1] for line in headline_lines) + max(0, len(headline_lines) - 1) * 24
body_h = sum(text_size(draw, line, body_font)[1] for line in body_lines) + max(0, len(body_lines) - 1) * 18
content_h = 62 + 74 + headline_h + 44 + 12 + 62 + body_h
content_y = round((canvas_rgba.height - content_h) * 0.5)

pill_w = text_size(draw, scene["eyebrow"], eyebrow_font)[0] + 58
rounded_rect(draw, (text_x, content_y, text_x + pill_w, content_y + 62), 31, blue_soft)
draw.text((text_x + 29, content_y + 13), scene["eyebrow"], font=eyebrow_font, fill=blue)

y = content_y + 136
y = draw_wrapped(draw, (text_x, y), scene["headline"], headline_font, ink, text_w, 24)
y += 44
draw.rectangle((text_x, y, text_x + 160, y + 12), fill=blue)
y += 62
y = draw_wrapped(draw, (text_x, y), scene["body"], body_font, muted, 760, 18)

max_width = 1280
max_height = 1640
scale = min(max_width / width, max_height / height, 2.05)
window = raw.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)

shadow = Image.new("RGBA", (window.width + 150, window.height + 150), (0, 0, 0, 0))
shadow_alpha = Image.new("L", window.size, 30)
shadow.paste((15, 23, 42, 30), (75, 75), shadow_alpha)
shadow = shadow.filter(ImageFilter.GaussianBlur(24))

window_x = round(2095 - window.width * 0.5)
window_y = round((canvas_rgba.height - window.height) * 0.5)
canvas_rgba.alpha_composite(shadow, (window_x - 75, window_y - 75))
canvas_rgba.alpha_composite(window, (window_x, window_y))

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
  validate_and_compose "$raw_capture" "$app_store_capture" "$scenario"
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
