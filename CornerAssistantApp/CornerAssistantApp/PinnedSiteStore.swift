import Foundation

final class PinnedSiteStore {
    static let shared = PinnedSiteStore()

    private let defaultsKey = "CornerAssistant.PinnedSites"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [PinnedSite] {
        guard let data = defaults.data(forKey: defaultsKey) else {
            return []
        }

        do {
            return try decoder.decode([PinnedSite].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ sites: [PinnedSite]) {
        do {
            let data = try encoder.encode(sites)
            defaults.set(data, forKey: defaultsKey)
        } catch {
            // Ignore encoding errors for now
        }
    }
}
