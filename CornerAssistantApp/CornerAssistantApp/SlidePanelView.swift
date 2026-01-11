import SwiftUI
import WebKit
import Combine
import AppKit

struct SlidePanelView: View {
    @EnvironmentObject private var localization: LocalizationManager
    @ObservedObject private var state: SlidePanelState
    @StateObject private var viewModel: SlidePanelViewModel
    @StateObject private var suggestionStore: SuggestionStore
    @State private var address: String = ""
    @FocusState private var isAddressFocused: Bool
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
    }

    private var sidebar: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 24)
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
                }
            }
            Divider()
                .frame(width: 18)
                .padding(.vertical, 8)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(viewModel.regularTabs) { tab in
                        SidebarButton(
                            isActive: tab.id == viewModel.activeTabID,
                            iconURL: tab.faviconURL,
                            fallbackSystemName: "globe",
                            accessibilityLabel: tab.title
                        ) {
                            select(tab: tab)
                        }
                        .contextMenu {
                            Button(localization.localized("context.close_tab")) {
                                viewModel.close(tab: tab)
                            }
                            Button(localization.localized("context.pin_tab")) {
                                viewModel.pin(tab: tab)
                            }
                            .disabled(!viewModel.canPin(tab: tab))
                        }
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

    func requestAddressFocus() {
        focusSubject.send(())
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
