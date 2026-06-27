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

CONFIGURATION=Debug "$RUN_SCRIPT" --verify
post_panel_command expand
sleep 1

/usr/bin/swift - <<'SWIFT'
import CoreGraphics
import Foundation

let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let matches = windows.compactMap { window -> String? in
    guard (window[kCGWindowOwnerName as String] as? String) == "Peek",
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          width > 100,
          height > 100 else {
        return nil
    }

    let id = window[kCGWindowNumber as String] ?? ""
    let layer = window[kCGWindowLayer as String] ?? ""
    return "window id=\(id) layer=\(layer) bounds=\(bounds)"
}

guard !matches.isEmpty else {
    fputs("Peek panel window was not visible after debug expand command.\n", stderr)
    exit(1)
}

print(matches.joined(separator: "\n"))
SWIFT
