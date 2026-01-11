import Foundation
import Combine

@MainActor
final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published private(set) var currentLanguage: AppLanguage

    private let defaultsKey = "CornerAssistantApp.PreferredLanguage"
    private var bundle: Bundle

    private init() {
        let savedIdentifier = UserDefaults.standard.string(forKey: defaultsKey)
        let initialLanguage: AppLanguage
        if let savedIdentifier,
           let savedLanguage = AppLanguage(rawValue: savedIdentifier) {
            initialLanguage = savedLanguage
        } else {
            initialLanguage = AppLanguage.resolvedDefault(from: Locale.preferredLanguages)
        }
        currentLanguage = initialLanguage
        bundle = LocalizationManager.makeBundle(for: initialLanguage)
    }

    func localized(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: nil, table: nil)
    }

    func use(language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
        bundle = LocalizationManager.makeBundle(for: language)
        UserDefaults.standard.set(language.rawValue, forKey: defaultsKey)
    }

    private static func makeBundle(for language: AppLanguage) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.resourceName, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }
}
