import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case japanese = "ja"

    var id: String { rawValue }

    var resourceName: String { rawValue }

    static func resolvedDefault(from preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            if let match = AppLanguage.matching(identifier: identifier) {
                return match
            }
        }
        return .english
    }

    private static func matching(identifier: String) -> AppLanguage? {
        guard !identifier.isEmpty else { return nil }

        let normalized = identifier.replacingOccurrences(of: "_", with: "-")

        if let language = AppLanguage(rawValue: normalized) {
            return language
        }

        let components = normalized.split(separator: "-")
        guard let languageCode = components.first else { return nil }
        switch languageCode.lowercased() {
        case "en":
            return .english
        case "zh":
            return .chineseSimplified
        case "ja":
            return .japanese
        default:
            return nil
        }
    }

    var displayKey: String {
        switch self {
        case .english:
            return "language.english"
        case .chineseSimplified:
            return "language.chinese_simplified"
        case .japanese:
            return "language.japanese"
        }
    }
}
