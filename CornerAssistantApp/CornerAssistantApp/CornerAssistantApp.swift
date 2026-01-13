import SwiftUI
import AppKit
import Combine

@main
struct CornerAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(LocalizationManager.shared)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: SlidePanelController?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var cornerMenuItems: [HotCorner: NSMenuItem] = [:]
    private var launchAtLoginMenuItem: NSMenuItem?
    private var localizationCancellable: AnyCancellable?
    private var appMenu: NSMenu?
    private var appMenuBarItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var editMenu: NSMenu?
    private var editMenuItem: NSMenuItem?
    private var cutMenuItem: NSMenuItem?
    private var copyMenuItem: NSMenuItem?
    private var pasteMenuItem: NSMenuItem?
    private var selectAllMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureApplication()
        LaunchAtLoginManager.shared.synchronize()
        updateLaunchMenuState()
        let controller = SlidePanelController(hotCorner: HotCornerStore.current)
        controller.start()
        self.controller = controller
        applyLocalization()

        localizationCancellable = LocalizationManager.shared.$currentLanguage
            .sink { [weak self] _ in
                self?.applyLocalization()
            }
    }

    func applicationWillTerminate(_ notification: Notification) {
        localizationCancellable?.cancel()
        controller?.stop()
    }

    private func configureApplication() {
        NSApp.setActivationPolicy(.accessory)
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        appMenuBarItem = appMenuItem

        let appMenu = NSMenu()
        let quitItem = NSMenuItem(
            title: "",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitItem)
        appMenuItem.submenu = appMenu
        self.appMenu = appMenu
        self.quitMenuItem = quitItem

        // 添加编辑菜单以支持标准编辑快捷键
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        self.editMenuItem = editMenuItem
        
        let editMenu = NSMenu(title: LocalizationManager.shared.localized("menu.edit"))
        editMenuItem.submenu = editMenu
        self.editMenu = editMenu
        
        // Cut (Command+X)
        let cutItem = NSMenuItem(
            title: LocalizationManager.shared.localized("menu.cut"),
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        // 不需要显式设置 keyEquivalentModifierMask，默认就是 .command
        cutItem.target = nil // nil target 让事件路由到响应链
        editMenu.addItem(cutItem)
        self.cutMenuItem = cutItem
        
        // Copy (Command+C)
        let copyItem = NSMenuItem(
            title: LocalizationManager.shared.localized("menu.copy"),
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        copyItem.target = nil
        editMenu.addItem(copyItem)
        self.copyMenuItem = copyItem
        
        // Paste (Command+V)
        let pasteItem = NSMenuItem(
            title: LocalizationManager.shared.localized("menu.paste"),
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        pasteItem.target = nil
        editMenu.addItem(pasteItem)
        self.pasteMenuItem = pasteItem
        
        editMenu.addItem(.separator())
        
        // Select All (Command+A)
        let selectAllItem = NSMenuItem(
            title: LocalizationManager.shared.localized("menu.select_all"),
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        selectAllItem.target = nil
        editMenu.addItem(selectAllItem)
        self.selectAllMenuItem = selectAllItem

        NSApp.mainMenu = mainMenu

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let appName = LocalizationManager.shared.localized("app.name")
        let image = createMenuBarIcon()
        image.accessibilityDescription = appName
        statusItem.button?.image = image
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
            updateLaunchMenuState()
            statusMenu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
        } else {
            controller.togglePanel()
        }
    }

    @objc private func selectHotCorner(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let corner = HotCorner(rawValue: raw),
              let controller else { return }

        HotCornerStore.current = corner
        controller.updateHotCorner(corner)
        updateCornerMenuSelection()
    }

    private func makeStatusMenu() -> NSMenu {
        let localization = LocalizationManager.shared
        let menu = NSMenu()
        menu.appearance = NSAppearance(named: .aqua)

        let cornerMenuItem = NSMenuItem(title: localization.localized("status.hot_corner"), action: nil, keyEquivalent: "")
        let cornerSubmenu = NSMenu()
        cornerSubmenu.appearance = NSAppearance(named: .aqua)
        cornerMenuItems.removeAll()
        for corner in HotCorner.allCases {
            let item = NSMenuItem(title: corner.localizedName(using: localization),
                                  action: #selector(selectHotCorner(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.representedObject = corner.rawValue
            cornerSubmenu.addItem(item)
            cornerMenuItems[corner] = item
        }
        cornerMenuItem.submenu = cornerSubmenu
        menu.addItem(cornerMenuItem)

        let launchItem = NSMenuItem(title: localization.localized("status.launch_at_login"), action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        menu.addItem(launchItem)
        launchAtLoginMenuItem = launchItem

        menu.addItem(.separator())
        let quitTitle = localization.localized("status.quit")
        let quitItem = NSMenuItem(title: quitTitle,
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    private func updateCornerMenuSelection() {
        let current = HotCornerStore.current
        for (corner, item) in cornerMenuItems {
            item.state = (corner == current) ? .on : .off
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let manager = LaunchAtLoginManager.shared
        if manager.isEnabled {
            manager.disable()
        } else {
            manager.enable()
        }
        updateLaunchMenuState()
    }

    private func updateLaunchMenuState() {
        let enabled = LaunchAtLoginManager.shared.isEnabled
        launchAtLoginMenuItem?.state = enabled ? .on : .off
    }

    private func applyLocalization() {
        let localization = LocalizationManager.shared
        let appName = localization.localized("app.name")

        appMenu?.title = appName
        appMenuBarItem?.title = appName
        let quitFormat = localization.localized("menu.quit")
        quitMenuItem?.title = String(format: quitFormat, appName)

        // 更新编辑菜单本地化
        editMenu?.title = localization.localized("menu.edit")
        editMenuItem?.title = localization.localized("menu.edit")
        cutMenuItem?.title = localization.localized("menu.cut")
        copyMenuItem?.title = localization.localized("menu.copy")
        pasteMenuItem?.title = localization.localized("menu.paste")
        selectAllMenuItem?.title = localization.localized("menu.select_all")

        statusItem?.button?.toolTip = localization.localized("status.tooltip")
        statusItem?.button?.setAccessibilityLabel(appName)
        let image = createMenuBarIcon()
        image.accessibilityDescription = appName
        statusItem?.button?.image = image

        statusMenu = makeStatusMenu()
        updateCornerMenuSelection()
        updateLaunchMenuState()
    }

    private func createMenuBarIcon() -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.set()
            
            // 外框：正方形，圆角更加圆滑
            // Use a 16x16 square centered in 22x22
            let frameRect = NSRect(x: 3, y: 3, width: 16, height: 16)
            let framePath = NSBezierPath(roundedRect: frameRect, xRadius: 4.5, yRadius: 4.5)
            framePath.lineWidth = 1.5
            framePath.stroke()
            
            // 内部：左侧胶囊形状，代表侧边栏
            // Update to match App Icon: Fatter and shifted left
            // Previous: x: 6, width: 4
            // New: x: 4.5, width: 6.5 (More prominent)
            let pillRect = NSRect(x: 4.5, y: 6, width: 6.5, height: 10)
            let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 3.25, yRadius: 3.25)
            pillPath.fill()
            
            return true
        }
        image.isTemplate = true
        return image
    }
}

struct SettingsView: View {
    @EnvironmentObject private var localization: LocalizationManager

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { localization.currentLanguage },
            set: { localization.use(language: $0) }
        )
    }

    var body: some View {
        Form {
            Section {
                Text(localization.localized("app.name"))
                    .font(.title2)
                Text(localization.localized("app.description"))
                    .foregroundColor(.secondary)
            }

            Section(header: Text(localization.localized("settings.language"))) {
                Picker("", selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(localization.localized(language.displayKey))
                            .tag(language)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .padding()
        .frame(width: 360)
    }
}
