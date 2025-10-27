import Foundation
import Combine

@MainActor
final class SlidePanelViewModel: ObservableObject {
    @Published private(set) var tabs: [BrowserTab]
    @Published var activeTabID: UUID
    @Published var showingLauncher: Bool = true

    init() {
        let initialTab = BrowserTab()
        tabs = [initialTab]
        activeTabID = initialTab.id
    }

    var activeTab: BrowserTab {
        guard let tab = tabs.first(where: { $0.id == activeTabID }) else {
            // 如果意外丢失，创建新标签
            let newTab = BrowserTab()
            tabs = [newTab]
            activeTabID = newTab.id
            return newTab
        }
        return tab
    }

    func select(tab: BrowserTab) {
        activeTabID = tab.id
        showingLauncher = tab.url == nil
    }

    func addTab() {
        let tab = BrowserTab()
        tabs.append(tab)
        activeTabID = tab.id
        showingLauncher = true
    }

    func close(tab: BrowserTab) {
        guard tabs.count > 1 else {
            tab.addressText = ""
            tab.url = nil
            tab.faviconURL = nil
            showingLauncher = true
            return
        }

        tabs.removeAll(where: { $0.id == tab.id })
        if tab.id == activeTabID, let first = tabs.first {
            activeTabID = first.id
            showingLauncher = first.url == nil
        }
    }

    func updateActiveTabURL(_ url: URL, addressText: String?) {
        guard let index = tabs.firstIndex(where: { $0.id == activeTabID }) else { return }
        tabs[index].url = url
        tabs[index].addressText = addressText ?? url.absoluteString
        if let host = url.host {
            tabs[index].faviconURL = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
        }
    }
}
