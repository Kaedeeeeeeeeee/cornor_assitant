import Foundation

enum HotCornerStore {
    private static let key = "CornerAssistant.HotCorner"

    static var current: HotCorner {
        get {
            if let raw = UserDefaults.standard.string(forKey: key),
               let corner = HotCorner(rawValue: raw) {
                return corner
            }
            return .bottomLeft
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}
