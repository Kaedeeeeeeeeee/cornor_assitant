import SwiftUI
import WebKit
import Combine
import AppKit
import UniformTypeIdentifiers

struct SlidePanelView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @ObservedObject private var state: SlidePanelState
    @StateObject private var viewModel: SlidePanelViewModel
    @StateObject private var suggestionStore: SuggestionStore
    @State private var address: String = ""
    @FocusState private var isAddressFocused: Bool
    @State private var draggingPinnedSiteID: String?
    @State private var draggingTabID: UUID?
    private let searchProvider: any SearchProvider

    init(state: SlidePanelState) {
        let provider: any SearchProvider = GoogleSearchProvider()
        self.searchProvider = provider
        _state = ObservedObject(initialValue: state)
        _viewModel = StateObject(wrappedValue: SlidePanelViewModel())
        _suggestionStore = StateObject(wrappedValue: SuggestionStore(provider: provider))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
            contentArea
                .clipShape(UnevenRoundedRect(topLeft: 18, bottomLeft: 18))
                .overlay(
                    UnevenRoundedRect(topLeft: 18, bottomLeft: 18)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            syncAddressWithActiveTab()
        }
        .onReceive(state.focusEvents) { _ in
            guard viewModel.showingLauncher else { return }
            DispatchQueue.main.async {
                isAddressFocused = true
            }
        }
        .onChange(of: isAddressFocused) {
            if !isAddressFocused {
                suggestionStore.clear()
            }
        }
        .onReceive(viewModel.$showingLauncher) { isLauncherVisible in
            if !isLauncherVisible {
                suggestionStore.clear()
            } else {
                DispatchQueue.main.async {
                    isAddressFocused = true
                }
            }
        }
        .onReceive(viewModel.$activeTabID) { _ in
            syncAddressWithActiveTab()
        }
        #if DEBUG
        .onReceive(state.debugScenarioEvents) { scenario in
            applyDebugScenario(scenario)
        }
        #endif
    }

    private var sidebar: some View {
        VStack(spacing: 8) {
            // 图钉按钮放在侧边栏最上方
            PinButton(isPinned: $state.isPinned)
                .padding(.top, 12)
            
            Divider()
                .frame(width: 18)
                .padding(.vertical, 4)
            
            VStack(spacing: 12) {
                ForEach(viewModel.pinnedSites) { site in
                    SidebarButton(
                        isActive: viewModel.isPinnedActive(site),
                        iconURL: site.faviconURL,
                        fallbackSystemName: "app",
                        accessibilityLabel: site.name
                    ) {
                        openPinned(site)
                    }
                    .contextMenu {
                        Button(localization.localized("context.remove_pinned")) {
                            viewModel.unpin(site: site)
                        }
                    }
                    .opacity(draggingPinnedSiteID == site.id ? 0.5 : 1.0)
                    .onDrag {
                        draggingPinnedSiteID = site.id
                        return NSItemProvider(object: site.id as NSString)
                    }
                    .onDrop(of: [.text], delegate: PinnedSiteDropDelegate(
                        site: site,
                        viewModel: viewModel,
                        draggingID: $draggingPinnedSiteID
                    ))
                }
            }
            Divider()
                .frame(width: 18)
                .padding(.vertical, 8)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(viewModel.regularTabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == viewModel.activeTabID,
                            canPin: viewModel.canPin(tab: tab),
                            onSelect: { select(tab: tab) },
                            onClose: { viewModel.close(tab: tab) },
                            onPin: { viewModel.pin(tab: tab) }
                        )
                        .opacity(draggingTabID == tab.id ? 0.5 : 1.0)
                        .onDrag {
                            draggingTabID = tab.id
                            return NSItemProvider(object: tab.id.uuidString as NSString)
                        }
                        .onDrop(of: [.text], delegate: RegularTabDropDelegate(
                            tab: tab,
                            viewModel: viewModel,
                            draggingID: $draggingTabID
                        ))
                    }
                    SidebarButton(
                        isActive: viewModel.showingLauncher,
                        iconURL: nil,
                        fallbackSystemName: "plus",
                        accessibilityLabel: localization.localized("sidebar.new_tab")
                    ) {
                        createNewTab()
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .padding(.bottom, 14)
        .frame(width: 28)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var contentArea: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.showingLauncher {
                LauncherView(
                    text: $address,
                    isFocused: $isAddressFocused,
                    suggestions: suggestionStore.suggestions,
                    onSubmit: { loadAddress() },
                    onSuggestionSelect: { suggestion in
                        applySuggestion(suggestion)
                    },
                    onChange: { newValue in
                        suggestionStore.update(query: newValue)
                    },
                    onFocusLost: {
                        suggestionStore.clear()
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                WebViewContainer(webView: viewModel.activeTab.webViewStore.webView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showingLauncher)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func openPinned(_ site: PinnedSite) {
        let tab = viewModel.activatePinned(site: site)
        suggestionStore.clear()
        if let currentURL = tab.url {
            address = tab.addressText.isEmpty ? currentURL.absoluteString : tab.addressText
        } else {
            address = site.url
        }
    }

    private func select(tab: BrowserTab) {
        viewModel.select(tab: tab)
        address = tab.addressText
        suggestionStore.clear()
        if viewModel.showingLauncher {
            DispatchQueue.main.async {
                isAddressFocused = true
            }
        }
    }

    private func createNewTab() {
        viewModel.addTab()
        suggestionStore.clear()
        address = ""
        DispatchQueue.main.async {
            isAddressFocused = true
        }
    }

    private func loadAddress() {
        suggestionStore.clear()

        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let targetURL: URL?

        if let directURL = searchProvider.normalizedURL(from: trimmed) {
            targetURL = directURL
            address = directURL.absoluteString
        } else {
            targetURL = searchProvider.searchURL(for: trimmed)
        }

        guard let url = targetURL else { return }
        let activeTab = viewModel.activeTab
        activeTab.addressText = address
        activeTab.webViewStore.load(url: url)
        viewModel.updateActiveTabURL(url, addressText: address)
        viewModel.showingLauncher = false
        isAddressFocused = false
    }

    private func applySuggestion(_ suggestion: String) {
        address = suggestion
        loadAddress()
    }

    private func syncAddressWithActiveTab() {
        address = viewModel.activeTab.addressText
    }

    #if DEBUG
    private func applyDebugScenario(_ scenario: String) {
        suggestionStore.clear()

        switch scenario {
        case "launcher":
            viewModel.addTab()
            address = ""
            viewModel.showingLauncher = true
            state.isPinned = false
        case "search":
            viewModel.addTab()
            address = "macOS focus workspace"
            suggestionStore.suggestions = [
                "macOS focus workspace",
                "macOS menu bar browser",
                "macOS productivity shortcuts"
            ]
            viewModel.showingLauncher = true
            state.isPinned = false
        case "web":
            loadDebugPage(
                title: "Corner Peek Notes",
                urlString: "https://cornerpeek.local/notes",
                bodyTitle: "Research notes",
                bodySubtitle: "A lightweight page opened from the screen edge.",
                cards: ["Project brief", "Reference links", "Daily checklist"]
            )
            state.isPinned = false
        case "tabs":
            loadDebugPage(
                title: "Team Workspace",
                urlString: "https://peek.local/workspace",
                bodyTitle: "Team workspace",
                bodySubtitle: "Pinned sites and quick tabs stay close without taking over the desktop.",
                cards: ["Docs", "Chat", "Dashboard"]
            )
            viewModel.addTab()
            loadDebugPage(
                title: "Release Checklist",
                urlString: "https://peek.local/release",
                bodyTitle: "Release checklist",
                bodySubtitle: "A second tab for short review tasks.",
                cards: ["Metadata", "Screenshots", "Review notes"]
            )
            state.isPinned = false
        case "pinned":
            loadDebugPage(
                title: "Pinned Tools",
                urlString: "https://peek.local/pinned",
                bodyTitle: "Pinned tools",
                bodySubtitle: "Keep everyday tools one click away from the side rail.",
                cards: ["AI tools", "Docs", "Team chat"]
            )
            state.isPinned = true
        default:
            break
        }
    }

    private func loadDebugPage(
        title: String,
        urlString: String,
        bodyTitle: String,
        bodySubtitle: String,
        cards: [String]
    ) {
        guard let url = URL(string: urlString) else { return }
        let cardHTML = cards
            .map { "<li>\($0)</li>" }
            .joined()
        let html = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <title>\(title)</title>
          <style>
            :root { color-scheme: light dark; }
            body {
              margin: 0;
              min-height: 100vh;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              background: #f6f8fa;
              color: #18202a;
            }
            main { max-width: 780px; margin: 0 auto; padding: 72px 56px; }
            h1 { font-size: 42px; line-height: 1.08; margin: 0 0 18px; letter-spacing: 0; }
            p { font-size: 18px; line-height: 1.6; margin: 0 0 34px; color: #52606d; }
            ul { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; padding: 0; margin: 0; }
            li {
              list-style: none;
              border: 1px solid rgba(24, 32, 42, 0.12);
              border-radius: 8px;
              padding: 18px;
              background: rgba(255, 255, 255, 0.82);
              font-weight: 600;
            }
            @media (prefers-color-scheme: dark) {
              body { background: #11161d; color: #f4f6f8; }
              p { color: #a9b4bf; }
              li { background: rgba(255,255,255,0.08); border-color: rgba(255,255,255,0.14); }
            }
          </style>
        </head>
        <body>
          <main>
            <h1>\(bodyTitle)</h1>
            <p>\(bodySubtitle)</p>
            <ul>\(cardHTML)</ul>
          </main>
        </body>
        </html>
        """

        let tab = viewModel.activeTab
        tab.addressText = url.absoluteString
        tab.title = title
        tab.webViewStore.loadDebugHTML(html, baseURL: url, title: title)
        viewModel.updateActiveTabURL(url, addressText: url.absoluteString)
        viewModel.showingLauncher = false
        address = url.absoluteString
        isAddressFocused = false
    }
    #endif
}

// MARK: - WebView Hosting

private struct WebViewContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        attach(webView, to: container)
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if nsView.subviews.first !== webView {
            nsView.subviews.forEach { $0.removeFromSuperview() }
            attach(webView, to: nsView)
        }
    }

    private func attach(_ webView: WKWebView, to container: NSView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

// MARK: - Focus coordination

final class SlidePanelState: ObservableObject {
    private let focusSubject = PassthroughSubject<Void, Never>()
    fileprivate lazy var focusEvents: AnyPublisher<Void, Never> = focusSubject.eraseToAnyPublisher()
    #if DEBUG
    private let debugScenarioSubject = PassthroughSubject<String, Never>()
    fileprivate lazy var debugScenarioEvents: AnyPublisher<String, Never> = debugScenarioSubject.eraseToAnyPublisher()
    #endif
    
    /// 窗口是否被固定（固定后点击外部不会收起）
    @Published var isPinned: Bool = false

    func requestAddressFocus() {
        focusSubject.send(())
    }

    #if DEBUG
    func applyDebugScenario(_ scenario: String) {
        debugScenarioSubject.send(scenario)
    }
    #endif
}

// MARK: - Sidebar

private struct TabItemView: View {
    @ObservedObject var tab: BrowserTab
    let isActive: Bool
    let canPin: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onPin: () -> Void
    @EnvironmentObject private var localization: LocalizationManager

    var body: some View {
        SidebarButton(
            isActive: isActive,
            iconURL: tab.faviconURL,
            fallbackSystemName: "globe",
            accessibilityLabel: tab.title
        ) {
            onSelect()
        }
        .contextMenu {
            Button(localization.localized("context.close_tab")) {
                onClose()
            }
            Button(localization.localized("context.pin_tab")) {
                onPin()
            }
            .disabled(!canPin)
        }
    }
}

private struct SidebarButton: View {
    let isActive: Bool
    let iconURL: URL?
    let fallbackSystemName: String
    let accessibilityLabel: String
    let action: () -> Void
    @State private var image: NSImage?

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Color.accentColor.opacity(0.16) : Color.clear)
                    .frame(width: 22, height: 22)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                } else {
                    Image(systemName: fallbackSystemName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isActive ? .accentColor : .secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .task(id: iconURL) {
            if let iconURL {
                image = await loadFavicon(from: iconURL)
            } else {
                image = nil
            }
        }
    }

    private func loadFavicon(from url: URL) async -> NSImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data) else { return nil }
            return image
        } catch {
            return nil
        }
    }
}

// MARK: - Drop Delegates

private struct PinnedSiteDropDelegate: DropDelegate {
    let site: PinnedSite
    let viewModel: SlidePanelViewModel
    @Binding var draggingID: String?

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != site.id,
              let from = viewModel.pinnedSites.firstIndex(where: { $0.id == draggingID }),
              let to = viewModel.pinnedSites.firstIndex(where: { $0.id == site.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.movePinnedSite(from: from, to: to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingID != nil
    }
}

private struct RegularTabDropDelegate: DropDelegate {
    let tab: BrowserTab
    let viewModel: SlidePanelViewModel
    @Binding var draggingID: UUID?

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != tab.id else { return }
        let regularTabs = viewModel.regularTabs
        guard let from = regularTabs.firstIndex(where: { $0.id == draggingID }),
              let to = regularTabs.firstIndex(where: { $0.id == tab.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.moveRegularTab(from: from, to: to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingID != nil
    }
}

// MARK: - Pin Button

private struct PinButton: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var isPinned: Bool
    @State private var isHovering = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isPinned.toggle()
            }
        } label: {
            ZStack {
                // 背景：只在悬停时显示
                Circle()
                    .fill(isHovering ? Color.secondary.opacity(0.1) : Color.clear)
                    .frame(width: 28, height: 28)
                
                // 图钉图标
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isPinned ? .accentColor : .secondary)
                    .rotationEffect(.degrees(isPinned ? 0 : 45))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(isPinned ? localization.localized("pin.unpin_window") : localization.localized("pin.window"))
        .accessibilityLabel(isPinned ? localization.localized("pin.unpin_window") : localization.localized("pin.window"))
    }
}

// MARK: - Launcher

private struct LauncherView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let suggestions: [String]
    let onSubmit: () -> Void
    let onSuggestionSelect: (String) -> Void
    let onChange: (String) -> Void
    let onFocusLost: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 72)
            VStack(spacing: 12) {
                searchField
                if !suggestions.isEmpty {
                    SuggestionsList(
                        suggestions: suggestions,
                        onSelect: onSuggestionSelect
                    )
                    .padding(.top, 12)
                }
            }
            .frame(maxWidth: 520)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: isFocused) {
            if !isFocused {
                onFocusLost()
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.secondary.opacity(0.7))
            TextField(localization.localized("launcher.placeholder"), text: $text, onCommit: onSubmit)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .submitLabel(.go)
                .onChange(of: text) {
                    onChange(text)
                }
                .onSubmit(onSubmit)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.secondary.opacity(0.7))
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localization.localized("launcher.clear"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
    }
}

private struct SuggestionsList: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                Button {
                    onSelect(suggestion)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text(suggestion)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if index < suggestions.count - 1 {
                    Divider()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
        .padding(.horizontal, 32)
    }
}
