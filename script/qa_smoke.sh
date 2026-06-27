#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_SCRIPT="$ROOT_DIR/script/build_and_run.sh"
DEBUG_NOTIFICATION="com.shifeng.peek.debug.panelCommand"

post_panel_command() {
  local command="$1"
  /usr/bin/swift -e 'import Foundation; let name = Notification.Name(CommandLine.arguments[1]); let command = CommandLine.arguments[2]; DistributedNotificationCenter.default().postNotificationName(name, object: nil, userInfo: ["command": command], deliverImmediately: true); Thread.sleep(forTimeInterval: 1.0)' "$DEBUG_NOTIFICATION" "$command"
}

trap 'post_panel_command collapse >/dev/null 2>&1 || true' EXIT

assert_status_item() {
  /usr/bin/osascript <<'APPLESCRIPT'
tell application "System Events"
    if UI elements enabled is false then
        error "Accessibility UI scripting is disabled"
    end if

    if not (exists process "Peek") then
        error "Peek process is not visible to System Events"
    end if

    tell process "Peek"
        set summaries to {}
        set foundStatusItem to false
        repeat with menuBar in menu bars
            repeat with menuBarItem in menu bar items of menuBar
                set titleText to ""
                set descriptionText to ""
                set positionText to ""
                set sizeText to ""
                set itemWidth to 0
                set itemHeight to 0

                try
                    set titleText to title of menuBarItem as text
                end try
                try
                    set descriptionText to description of menuBarItem as text
                end try
                try
                    set itemPosition to position of menuBarItem
                    set itemSize to size of menuBarItem
                    set itemWidth to item 1 of itemSize
                    set itemHeight to item 2 of itemSize
                    set positionText to "x:" & (item 1 of itemPosition) & " y:" & (item 2 of itemPosition)
                    set sizeText to "w:" & itemWidth & " h:" & itemHeight
                end try

                if descriptionText is "Peek" and itemWidth > 0 and itemHeight > 0 then
                    set foundStatusItem to true
                    set end of summaries to "title=" & titleText & " description=" & descriptionText & " " & positionText & " " & sizeText
                end if
            end repeat
        end repeat

        if foundStatusItem is false then
            error "Peek status item was not found in menu bar accessibility tree"
        end if

        return summaries as text
    end tell
end tell
APPLESCRIPT
}

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

assert_panel_hidden() {
  /usr/bin/swift - <<'SWIFT'
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let matches = windows.compactMap { window -> (id: Any, x: Double, y: Double, width: Double, height: Double)? in
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
    return (id, x, y, width, height)
}

guard matches.isEmpty else {
    let descriptions = matches.map { "id=\($0.id) x=\(Int($0.x)) y=\(Int($0.y)) width=\(Int($0.width)) height=\(Int($0.height))" }
    fputs("Peek panel window was visible when it should be hidden: \(descriptions.joined(separator: ", "))\n", stderr)
    exit(1)
}

print("panel_hidden=true")
SWIFT
}

CONFIGURATION=Debug "$RUN_SCRIPT" --verify

status_item_summary="$(assert_status_item)"
echo "status_item=$status_item_summary"

post_panel_command "corner:bottomLeft"
assert_panel_hidden

for corner in bottomLeft bottomRight topLeft topRight; do
  post_panel_command "corner:$corner"
  sleep 1
  post_panel_command expand
  sleep 1
  assert_panel_window "$corner"
done

echo "qa_smoke passed"
