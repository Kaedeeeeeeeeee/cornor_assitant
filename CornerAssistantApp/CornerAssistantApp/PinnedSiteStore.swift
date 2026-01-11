import Foundation

enum PinnedSiteStore {
    private static let defaultsKey = "CornerAssistant.PinnedSites"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func load() -> [PinnedSite] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else {
            return []
        }
        do {
            return try decoder.decode([PinnedSite].self, from: data)
        } catch {
            return []
        }
    }

    static func save(_ sites: [PinnedSite]) {
        do {
            let data = try encoder.encode(sites)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            // ignore encoding errors for now
        }
    }
}
