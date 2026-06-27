#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
DEBUG_NOTIFICATION="com.shifeng.peek.debug.panelCommand"

post_panel_command() {
  local command="$1"
  /usr/bin/swift -e 'import Foundation; let name = Notification.Name(CommandLine.arguments[1]); let command = CommandLine.arguments[2]; DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: ["command": command], deliverImmediately: true); Thread.sleep(forTimeInterval: 0.2)' "$DEBUG_NOTIFICATION" "$command"
}

trap 'post_panel_command collapse >/dev/null 2>&1 || true' EXIT

assert_panel_window() {
  local corner="$1"
  /usr/bin/swift - "$corner" <<'SWIFT'
import AppKit
import CoreGraphics
import Foundation

let corner = CommandLine.arguments[1]
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let matches = windows.compactMap { window -> (id: Any, layer: Any, x: Double, y: Double, width: Double, height: Double)? in
    guard (window[kCGWindowOwnerName as String] as? String) == "Peek",
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let x = bounds["X"] as? Double,
          let y = bounds["Y"] as? Double,
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          width > 100,
          height > 100 else {
        return nil
    }

    let id = window[kCGWindowNumber as String] ?? ""
    let layer = window[kCGWindowLayer as String] ?? ""
    return (id, layer, x, y, width, height)
}

guard let match = matches.first else {
    fputs("Peek panel window was not visible after debug expand command.\n", stderr)
    exit(1)
}

guard let screen = NSScreen.main else {
    fputs("No main screen available.\n", stderr)
    exit(1)
}

let displayBounds = CGDisplayBounds(CGMainDisplayID())
let leftDistance = match.x - displayBounds.minX
let rightDistance = displayBounds.maxX - (match.x + match.width)
let topDistance = match.y - displayBounds.minY
let bottomDistance = displayBounds.maxY - (match.y + match.height) - screen.visibleFrame.minY
let tolerance = 90.0

let horizontalOK: Bool
let verticalOK: Bool

switch corner {
case "bottomLeft", "topLeft":
    horizontalOK = abs(leftDistance) <= tolerance
case "bottomRight", "topRight":
    horizontalOK = abs(rightDistance) <= tolerance
default:
    fputs("Unknown corner: \(corner)\n", stderr)
    exit(2)
}

switch corner {
case "topLeft", "topRight":
    verticalOK = abs(topDistance) <= tolerance
case "bottomLeft", "bottomRight":
    verticalOK = abs(bottomDistance) <= tolerance
default:
    fputs("Unknown corner: \(corner)\n", stderr)
    exit(2)
}

guard horizontalOK && verticalOK else {
    fputs("Peek panel frame did not match \(corner): x=\(match.x) y=\(match.y) width=\(match.width) height=\(match.height) left=\(leftDistance) right=\(rightDistance) top=\(topDistance) bottom=\(bottomDistance)\n", stderr)
    exit(1)
}

print("corner=\(corner) window id=\(match.id) layer=\(match.layer) bounds=x:\(Int(match.x)) y:\(Int(match.y)) width:\(Int(match.width)) height:\(Int(match.height))")
SWIFT
}

CONFIGURATION=Debug "$RUN_SCRIPT" --verify

for corner in bottomLeft bottomRight topLeft topRight; do
  post_panel_command "corner:$corner"
  post_panel_command expand
  sleep 1
  assert_panel_window "$corner"
done

echo "qa_smoke passed"
