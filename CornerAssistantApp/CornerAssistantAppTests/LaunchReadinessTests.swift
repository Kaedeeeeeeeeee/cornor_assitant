import XCTest
@testable import Peek

final class LaunchReadinessTests: XCTestCase {
    func testAppLanguageResolutionCoversLaunchLocales() {
        XCTAssertEqual(AppLanguage.resolvedDefault(from: ["en-US"]), .english)
        XCTAssertEqual(AppLanguage.resolvedDefault(from: ["zh-Hans-CN"]), .chineseSimplified)
        XCTAssertEqual(AppLanguage.resolvedDefault(from: ["ja-JP"]), .japanese)
        XCTAssertEqual(AppLanguage.resolvedDefault(from: ["fr-FR", "de-DE"]), .english)
    }

    func testLocalizationBundlesHaveMatchingKeys() throws {
        let dictionaries = try AppLanguage.allCases.reduce(into: [AppLanguage: [String: String]]()) { result, language in
            result[language] = try localizedStrings(for: language)
        }

        let referenceKeys = Set(try XCTUnwrap(dictionaries[.english]).keys)
        XCTAssertFalse(referenceKeys.isEmpty)

        for language in AppLanguage.allCases {
            let strings = try XCTUnwrap(dictionaries[language])
            XCTAssertEqual(Set(strings.keys), referenceKeys, "\(language.rawValue) localization keys drifted")
            XCTAssertTrue(strings.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        }
    }

    func testCriticalLaunchLocalizationKeysExist() throws {
        let requiredKeys = [
            "app.name",
            "app.description",
            "status.tooltip",
            "status.hot_corner",
            "status.launch_at_login",
            "status.language",
            "launcher.placeholder",
            "sidebar.new_tab",
            "pin.window",
            "pin.unpin_window"
        ]

        for language in AppLanguage.allCases {
            let strings = try localizedStrings(for: language)
            for key in requiredKeys {
                XCTAssertNotNil(strings[key], "\(language.rawValue) is missing \(key)")
            }
        }
    }

    func testHotCornerLaunchOptionsRemainStable() {
        XCTAssertEqual(
            HotCorner.allCases.map(\.rawValue),
            ["topLeft", "topRight", "bottomLeft", "bottomRight"]
        )
    }

    private func localizedStrings(for language: AppLanguage) throws -> [String: String] {
        let lprojPath = try XCTUnwrap(Bundle.main.path(forResource: language.resourceName, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        let strings = NSDictionary(contentsOfFile: stringsPath) as? [String: String]
        return try XCTUnwrap(strings, "Could not parse \(language.rawValue) Localizable.strings")
    }
}
