import Foundation

struct PinnedSite: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let url: String

    init(name: String, url: String) {
        self.name = name
        self.url = url
        self.id = url.lowercased()
    }

    var host: String? {
        URL(string: url)?.host
    }

    var faviconURL: URL? {
        guard let host else { return nil }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let url = try container.decode(String.self, forKey: .url)
        self.init(name: name, url: url)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
    }
}

extension PinnedSite {
    static let defaults: [PinnedSite] = [
        PinnedSite(name: "ChatGPT", url: "https://chatgpt.com/"),
        PinnedSite(name: "Notion", url: "https://www.notion.so/"),
        PinnedSite(name: "Slack", url: "https://app.slack.com/client/")
    ]
}
