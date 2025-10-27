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

    init(webViewStore: WebViewStore) {
        self.webViewStore = webViewStore
        self.title = "新标签页"
        self.addressText = ""
        self.url = nil
        self.faviconURL = nil

        webViewStore.onTitleChange = { [weak self] title in
            guard let self else { return }
            self.title = title.isEmpty ? "新标签页" : title
        }

        webViewStore.onURLChange = { [weak self] url in
            guard let self else { return }
            self.url = url
            self.addressText = url.absoluteString
            if let host = url.host {
                self.faviconURL = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
            }
        }
    }
}
