import Foundation
import Combine

@MainActor
final class BrowserTab: ObservableObject, Identifiable {
    let id = UUID()
    let webViewStore: WebViewStore

    @Published var title: String
    @Published var url: URL?
    @Published var addressText: String
    @Published var faviconURL: URL?

    private var localizationCancellable: AnyCancellable?
    private var isUsingPlaceholderTitle = true

    init(webViewStore: WebViewStore) {
        self.webViewStore = webViewStore
        let placeholderTitle = LocalizationManager.shared.localized("tab.new_title")
        self.title = placeholderTitle
        self.addressText = ""
        self.url = nil
        self.faviconURL = nil

        webViewStore.onTitleChange = { [weak self] title in
            guard let self else { return }
            if title.isEmpty {
                self.title = LocalizationManager.shared.localized("tab.new_title")
                self.isUsingPlaceholderTitle = true
            } else {
                self.title = title
                self.isUsingPlaceholderTitle = false
            }
        }

        webViewStore.onURLChange = { [weak self] url in
            guard let self else { return }
            self.url = url
            self.addressText = url.absoluteString
            if let host = url.host {
                self.faviconURL = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
            }
        }

        localizationCancellable = LocalizationManager.shared.$currentLanguage
            .sink { [weak self] _ in
                guard let self else { return }
                if self.url == nil || self.isUsingPlaceholderTitle {
                    self.title = LocalizationManager.shared.localized("tab.new_title")
                    self.isUsingPlaceholderTitle = true
                }
            }
    }
}
