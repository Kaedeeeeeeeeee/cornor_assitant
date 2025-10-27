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
        NSApp.setActivationPolicy(.regular)

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
