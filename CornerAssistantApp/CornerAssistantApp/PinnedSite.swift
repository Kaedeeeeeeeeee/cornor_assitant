import Foundation

struct PinnedSite: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let url: String

    let customFaviconURL: String?

    init(name: String, url: String, customFaviconURL: String? = nil) {
        self.name = name
        self.url = url
        self.customFaviconURL = customFaviconURL
        self.id = url.lowercased()
    }

    var host: String? {
        URL(string: url)?.host
    }

    var faviconURL: URL? {
        if let custom = customFaviconURL, let url = URL(string: custom) {
            return url
        }
        guard let host else { return nil }
        return URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=128")
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case url
        case customFaviconURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let url = try container.decode(String.self, forKey: .url)
        let customFaviconURL = try container.decodeIfPresent(String.self, forKey: .customFaviconURL)
        self.init(name: name, url: url, customFaviconURL: customFaviconURL)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(customFaviconURL, forKey: .customFaviconURL)
    }
}

extension PinnedSite {
    static let defaults: [PinnedSite] = [
        PinnedSite(name: "ChatGPT", url: "https://chatgpt.com/"),
        PinnedSite(name: "Notion", url: "https://www.notion.so/"),
        PinnedSite(name: "Slack", url: "https://app.slack.com/client/")
    ]
}
