import Foundation
import Combine

@MainActor
final class SlidePanelViewModel: ObservableObject {
    @Published private(set) var tabs: [BrowserTab]
    @Published private(set) var pinnedSites: [PinnedSite] {
        didSet { PinnedSiteStore.save(pinnedSites) }
    }
    @Published var activeTabID: UUID
    @Published var showingLauncher: Bool

    private var pinnedTabIDs: [String: UUID] = [:] // pinnedSiteID -> tabID

    init(initialPinnedSites: [PinnedSite]? = nil) {
        let storedSites = PinnedSiteStore.load()
        let sites = storedSites.isEmpty ? (initialPinnedSites ?? PinnedSite.defaults) : storedSites

        var tabMappings: [String: UUID] = [:]
        var initialTabs: [BrowserTab] = []
        for site in sites {
            let tab = BrowserTab(webViewStore: WebViewStore())
            initialTabs.append(tab)
            tabMappings[site.id] = tab.id
        }

        var initialLauncherVisible = true

        if initialTabs.isEmpty {
            let tab = BrowserTab(webViewStore: WebViewStore())
            initialTabs = [tab]
            tabMappings = [:]
        }
        if let firstSite = sites.first,
           let firstTab = initialTabs.first,
           let url = URL(string: firstSite.url) {
            firstTab.addressText = firstSite.url
            firstTab.webViewStore.load(url: url)
            initialLauncherVisible = false
        }

        _tabs = Published(initialValue: initialTabs)
        _pinnedSites = Published(initialValue: sites)
        pinnedTabIDs = tabMappings
        let initialActiveID = initialTabs.first?.id ?? UUID()
        _activeTabID = Published(initialValue: initialActiveID)
        _showingLauncher = Published(initialValue: initialLauncherVisible)

    }

    var activeTab: BrowserTab {
        guard let tab = tabs.first(where: { $0.id == activeTabID }) else {
            let newTab = BrowserTab(webViewStore: WebViewStore())
            tabs.append(newTab)
            activeTabID = newTab.id
            return newTab
        }
        return tab
    }

    var regularTabs: [BrowserTab] {
        let pinnedIDs = Set(pinnedTabIDs.values)
        return tabs.filter { !pinnedIDs.contains($0.id) }
    }

    func isPinnedActive(_ site: PinnedSite) -> Bool {
        guard let tabID = pinnedTabIDs[site.id] else { return false }
        return tabID == activeTabID
    }

    func activatePinned(site: PinnedSite) -> BrowserTab {
        if let tabID = pinnedTabIDs[site.id],
           let tab = tabs.first(where: { $0.id == tabID }) {
            if tab.url == nil, let url = URL(string: site.url) {
                tab.addressText = site.url
                tab.webViewStore.load(url: url)
            }
            activeTabID = tabID
            showingLauncher = false
            return tab
        }

        let tab = BrowserTab(webViewStore: WebViewStore())
        tabs.insert(tab, at: 0)
        pinnedTabIDs[site.id] = tab.id
        if let url = URL(string: site.url) {
            tab.addressText = site.url
            tab.webViewStore.load(url: url)
        }
        activeTabID = tab.id
        showingLauncher = false
        return tab
    }

    func select(tab: BrowserTab) {
        activeTabID = tab.id
        showingLauncher = tab.url == nil
    }

    func addTab() {
        let tab = BrowserTab(webViewStore: WebViewStore())
        tabs.append(tab)
        activeTabID = tab.id
        showingLauncher = true
    }

    func close(tab: BrowserTab) {
        let pinnedIDs = Set(pinnedTabIDs.values)
        guard !pinnedIDs.contains(tab.id) else { return } // 固定站点暂不支持关闭

        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        tabs.remove(at: index)

        if tab.id == activeTabID {
            if let next = tabs.first {
                activeTabID = next.id
                showingLauncher = next.url == nil
            } else {
                addTab()
            }
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

    func canPin(tab: BrowserTab) -> Bool {
        guard let url = tab.url else { return false }
        return !pinnedSites.contains { $0.url.caseInsensitiveCompare(url.absoluteString) == .orderedSame }
    }

    func pin(tab: BrowserTab) {
        guard canPin(tab: tab), let url = tab.url else { return }

        let displayName: String = {
            let title = tab.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty { return title }
            if let host = url.host, !host.isEmpty { return host }
            return LocalizationManager.shared.localized("tab.pinned_fallback")
        }()

        let site = PinnedSite(name: displayName, url: url.absoluteString)
        pinnedSites.append(site)
        pinnedTabIDs[site.id] = tab.id
    }

    func unpin(site: PinnedSite) {
        pinnedSites.removeAll { $0.id == site.id }
        pinnedTabIDs.removeValue(forKey: site.id)
    }
}
