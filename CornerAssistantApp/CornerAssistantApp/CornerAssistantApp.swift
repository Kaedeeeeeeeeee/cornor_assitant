import SwiftUI
import AppKit

@main
struct CornerAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: SlidePanelController?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var cornerMenuItems: [HotCorner: NSMenuItem] = [:]
    private let hotCornerStore = HotCornerStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplication()
        let controller = SlidePanelController(hotCorner: hotCornerStore.current)
        controller.start()
        self.controller = controller
        updateCornerMenuSelection()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    private func configureApplication() {
        NSApp.setActivationPolicy(.accessory)
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "CornerAssistant")
        let quitTitle = "退出 CornerAssistant"
        let quitItem = NSMenuItem(
            title: quitTitle,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        NSApp.mainMenu = mainMenu

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.leftthird.inset.fill", accessibilityDescription: "CornerAssistant")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = "Toggle CornerAssistant"
        self.statusItem = statusItem
        statusMenu = makeStatusMenu()
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let controller else { return }
        guard let event = NSApp.currentEvent else {
            controller.togglePanel()
            return
        }

        if event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control)) {
            guard let button = statusItem?.button,
                  let statusMenu else { return }
            updateCornerMenuSelection()
            statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        } else {
            controller.togglePanel()
        }
    }

    @objc private func selectHotCorner(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let corner = HotCorner(rawValue: raw),
              let controller else { return }

        hotCornerStore.current = corner
        controller.updateHotCorner(corner)
        updateCornerMenuSelection()
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()

        let cornerMenuItem = NSMenuItem(title: "Hot Corner", action: nil, keyEquivalent: "")
        let cornerSubmenu = NSMenu()
        cornerMenuItems.removeAll()
        for corner in HotCorner.allCases {
            let item = NSMenuItem(title: corner.displayName,
                                  action: #selector(selectHotCorner(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = corner.rawValue
            cornerSubmenu.addItem(item)
            cornerMenuItems[corner] = item
        }
        cornerMenuItem.submenu = cornerSubmenu
        menu.addItem(cornerMenuItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit CornerAssistant",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    private func updateCornerMenuSelection() {
        let current = hotCornerStore.current
        for (corner, item) in cornerMenuItems {
            item.state = (corner == current) ? .on : .off
        }
    }
}


struct SettingsView: View {
    var body: some View {
        Form {
            Text("CornerAssistant")
                .font(.title2)
            Text("将光标移动到屏幕左下角以展开面板。点击面板外部即可收起。")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 320)
    }
}
