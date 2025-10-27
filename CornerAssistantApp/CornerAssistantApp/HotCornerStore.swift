import Foundation

final class HotCornerStore {
    static let shared = HotCornerStore()

    private let defaults: UserDefaults
    private let key = "CornerAssistant.HotCorner"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var current: HotCorner {
        get {
            if let raw = defaults.string(forKey: key),
               let corner = HotCorner(rawValue: raw) {
                return corner
            }
            return .bottomLeft
        }
        set {
            defaults.set(newValue.rawValue, forKey: key)
        }
    }
}
