import SwiftUI
import WebKit
import Combine
import AppKit

struct SlidePanelView: View {
    @ObservedObject private var state: SlidePanelState
    @StateObject private var viewModel: SlidePanelViewModel
    @StateObject private var suggestionStore: SuggestionStore
    @State private var address: String = ""
    @FocusState private var isAddressFocused: Bool
    private let searchProvider: GoogleSearchProvider
    private let pinnedSites: [PinnedSite] = [
        PinnedSite(name: "ChatGPT", url: "https://chatgpt.com/"),
        PinnedSite(name: "Notion", url: "https://www.notion.so/"),
        PinnedSite(name: "Slack", url: "https://app.slack.com/client/")
    ]

    init(state: SlidePanelState) {
        let provider = GoogleSearchProvider()
        self.searchProvider = provider
        _state = ObservedObject(initialValue: state)
        _viewModel = StateObject(wrappedValue: SlidePanelViewModel())
        _suggestionStore = StateObject(wrappedValue: SuggestionStore(provider: provider))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            sidebar
            Color(nsColor: .separatorColor)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            contentArea
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
        .onChange(of: isAddressFocused) { focused in
            if !focused {
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
    }

    private var sidebar: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 24)
            VStack(spacing: 12) {
                ForEach(pinnedSites) { site in
                    SidebarButton(
                        isActive: viewModel.activeTab.url?.host == site.url.hostFromString,
                        iconURL: site.faviconURL,
                        fallbackSystemName: "app",
                        accessibilityLabel: site.name
                    ) {
                        openPinned(site)
                    }
                }
            }
            Divider()
                .frame(width: 18)
                .padding(.vertical, 8)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(viewModel.tabs) { tab in
                        SidebarButton(
                            isActive: tab.id == viewModel.activeTabID,
                            iconURL: tab.faviconURL,
                            fallbackSystemName: "globe",
                            accessibilityLabel: tab.title
                        ) {
                            select(tab: tab)
                        }
                    }
                }
                .padding(.bottom, 12)
            }
            Spacer()
            SidebarButton(
                isActive: viewModel.showingLauncher,
                iconURL: nil,
                fallbackSystemName: "plus",
                accessibilityLabel: "新建标签"
            ) {
                createNewTab()
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
                WebViewContainer(state: state, webView: viewModel.activeTab.webViewStore.webView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                    .onDisappear {
                        state.updateActiveWebView(nil)
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.showingLauncher)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func openPinned(_ site: PinnedSite) {
        address = site.url
        loadAddress()
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
}

// MARK: - WebView Hosting

private struct WebViewContainer: NSViewRepresentable {
    let state: SlidePanelState
    let webView: WKWebView

    final class Coordinator {
        var didFocus = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        state.updateActiveWebView(webView)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if state.activeWebView !== nsView {
            state.updateActiveWebView(nsView)
        }

        if !context.coordinator.didFocus, let window = nsView.window {
            window.makeFirstResponder(nsView)
            context.coordinator.didFocus = true
        } else if nsView.window == nil {
            context.coordinator.didFocus = false
        }
    }
}

// MARK: - Focus coordination

final class SlidePanelState: ObservableObject {
    private let focusSubject = PassthroughSubject<Void, Never>()
    fileprivate lazy var focusEvents: AnyPublisher<Void, Never> = focusSubject.eraseToAnyPublisher()
    private weak var activeWebViewRef: WKWebView?

    var activeWebView: WKWebView? {
        activeWebViewRef
    }

    func requestAddressFocus() {
        focusSubject.send(())
    }

    func updateActiveWebView(_ webView: WKWebView?) {
        activeWebViewRef = webView
    }

    func focusActiveWebView() {
        guard let webView = activeWebViewRef,
              let window = webView.window else { return }

        if window.firstResponder !== webView {
            window.makeFirstResponder(webView)
        }
    }

    func performEditingCommand(_ action: Selector, sender: Any?) {
        guard let webView = activeWebViewRef else { return }

        if webView.tryToPerform(action, with: sender) {
            return
        }

        if let responder = findResponder(in: webView, capableOf: action) {
            responder.perform(action, with: sender)
        }
    }

    private func findResponder(in view: NSView, capableOf action: Selector) -> NSResponder? {
        if view.responds(to: action) {
            return view
        }

        for subview in view.subviews {
            if let responder = findResponder(in: subview, capableOf: action) {
                return responder
            }
        }
        return view.nextResponder?.responds(to: action) == true ? view.nextResponder : nil
    }
}

// MARK: - Sidebar

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

private struct PinnedSite: Identifiable {
    let id = UUID()
    let name: String
    let url: String

    var faviconURL: URL? {
        guard let host = URL(string: url)?.host else { return nil }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }
}

private extension String {
    var hostFromString: String? {
        URL(string: self)?.host
    }
}

// MARK: - Launcher

private struct LauncherView: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    let suggestions: [String]
    let onSubmit: () -> Void
    let onSuggestionSelect: (String) -> Void
    let onChange: (String) -> Void
    let onFocusLost: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 32)
            VStack(spacing: 12) {
                Text("快速访问网页")
                    .font(.title2)
                    .foregroundColor(.primary)
                Text("输入网址或关键字，或从左侧固定站点中选择。")
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("搜索或输入网址", text: $text, onCommit: onSubmit)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .submitLabel(.go)
                        .onChange(of: text, perform: onChange)
                        .onSubmit(onSubmit)
                    if !text.isEmpty {
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("清除输入")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )

                if !suggestions.isEmpty {
                    SuggestionsList(
                        suggestions: suggestions,
                        onSelect: onSuggestionSelect
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: isFocused) { focused in
            if !focused {
                onFocusLost()
            }
        }
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
