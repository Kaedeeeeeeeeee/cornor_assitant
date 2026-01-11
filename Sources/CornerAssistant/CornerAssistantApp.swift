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

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplication()
        let controller = SlidePanelController()
        controller.start()
        self.controller = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.stop()
    }

    private func configureApplication() {
        let didSetPolicy = NSApp.setActivationPolicy(.regular)
        if !didSetPolicy {
            NSLog("Failed to set activation policy to regular; current policy: \(NSApp.activationPolicy().rawValue)")
        }
        ensureApplicationActivation()

        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        mainMenu.addItem(editMenuItem)

        let appMenu = NSMenu(title: "CornerAssistant")
        let quitTitle = "退出 CornerAssistant"
        let quitItem = NSMenuItem(
            title: quitTitle,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu

        let editMenu = NSMenu(title: "编辑")
        let undoItem = NSMenuItem(
            title: "撤销",
            action: #selector(UndoManager.undo),
            keyEquivalent: "z"
        )
        undoItem.target = nil
        editMenu.addItem(undoItem)

        let redoItem = NSMenuItem(
            title: "重做",
            action: #selector(UndoManager.redo),
            keyEquivalent: "Z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        redoItem.target = nil
        editMenu.addItem(redoItem)

        editMenu.addItem(.separator())

        let cutItem = NSMenuItem(
            title: "剪切",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        cutItem.target = self
        cutItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(cutItem)

        let copyItem = NSMenuItem(
            title: "复制",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        copyItem.target = self
        copyItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(copyItem)

        let pasteItem = NSMenuItem(
            title: "粘贴",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        pasteItem.target = self
        pasteItem.keyEquivalentModifierMask = [.command]
        editMenu.addItem(pasteItem)

        let selectAllItem = NSMenuItem(
            title: "全选",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        selectAllItem.target = nil
        editMenu.addItem(selectAllItem)

        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
        ensureApplicationActivation()
    }

    private func ensureApplicationActivation() {
        if NSApp.activationPolicy() != NSApplication.ActivationPolicy.regular {
            _ = NSApp.setActivationPolicy(.regular)
        }
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func handleEditCommand(_ action: Selector, sender: Any?) {
        guard !isRoutingEditCommand else { return }
        isRoutingEditCommand = true
        defer { isRoutingEditCommand = false }

        controller?.prepareEditingCommand()

        if !NSApp.sendAction(action, to: nil, from: sender) {
            controller?.performEditingCommand(action, sender: sender)
        }
    }

    @IBAction func cut(_ sender: Any?) {
        handleEditCommand(#selector(NSText.cut(_:)), sender: sender)
    }

    @IBAction func copy(_ sender: Any?) {
        handleEditCommand(#selector(NSText.copy(_:)), sender: sender)
    }

    @IBAction func paste(_ sender: Any?) {
        handleEditCommand(#selector(NSText.paste(_:)), sender: sender)
    }

    private var isRoutingEditCommand = false
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let action = menuItem.action else { return false }
        if [
            #selector(NSText.cut(_:)),
            #selector(NSText.copy(_:)),
            #selector(NSText.paste(_:)),
            #selector(NSText.selectAll(_:)),
            #selector(UndoManager.undo),
            #selector(UndoManager.redo)
        ].contains(action) {
            // Keep core editing commands enabled so the responder chain inside WKWebView handles them.
            return true
        }
        return true
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
