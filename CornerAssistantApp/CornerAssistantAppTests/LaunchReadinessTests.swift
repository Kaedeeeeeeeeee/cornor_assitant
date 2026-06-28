import XCTest
@testable import Peek

final class LaunchReadinessTests: XCTestCase {
    private let hotCornerDefaultsKey = "CornerAssistant.HotCorner"
    private let languageDefaultsKey = "CornerAssistantApp.PreferredLanguage"

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

    func testStatusAndSettingsLocalizationCoverEveryLaunchLanguage() throws {
        for language in AppLanguage.allCases {
            let strings = try localizedStrings(for: language)
            XCTAssertNotNil(strings["settings.language"], "\(language.rawValue) is missing settings language label")

            for launchLanguage in AppLanguage.allCases {
                XCTAssertNotNil(
                    strings[launchLanguage.displayKey],
                    "\(language.rawValue) is missing display name for \(launchLanguage.rawValue)"
                )
            }

            for corner in HotCorner.allCases {
                let title = strings[hotCornerLocalizationKey(for: corner)]
                XCTAssertFalse(title?.isEmpty ?? true, "\(language.rawValue) has empty hot corner title for \(corner.rawValue)")
            }
        }
    }

    func testStatusMenuStructureCoversLaunchControls() throws {
        XCTAssertEqual(StatusMenuStructure.hotCorners, HotCorner.allCases)
        XCTAssertEqual(StatusMenuStructure.languages, AppLanguage.allCases)
        XCTAssertEqual(
            StatusMenuStructure.topLevelLocalizationKeys,
            ["status.hot_corner", "status.launch_at_login", "status.language", "status.quit"]
        )

        for language in AppLanguage.allCases {
            let strings = try localizedStrings(for: language)

            for key in StatusMenuStructure.topLevelLocalizationKeys {
                let title = strings[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertFalse(title?.isEmpty ?? true, "\(language.rawValue) is missing status menu title \(key)")
            }

            for corner in StatusMenuStructure.hotCorners {
                let title = strings[hotCornerLocalizationKey(for: corner)]?.trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertFalse(title?.isEmpty ?? true, "\(language.rawValue) is missing status menu corner \(corner.rawValue)")
            }

            for menuLanguage in StatusMenuStructure.languages {
                let title = strings[menuLanguage.displayKey]?.trimmingCharacters(in: .whitespacesAndNewlines)
                XCTAssertFalse(title?.isEmpty ?? true, "\(language.rawValue) is missing language menu title \(menuLanguage.rawValue)")
            }
        }
    }

    @MainActor
    func testLocalizationManagerSwitchesAndPersistsLaunchLanguages() {
        let manager = LocalizationManager.shared
        let defaults = UserDefaults.standard
        let previousLanguage = manager.currentLanguage
        let previousStoredValue = defaults.string(forKey: languageDefaultsKey)
        defer {
            manager.use(language: previousLanguage)
            if let previousStoredValue {
                defaults.set(previousStoredValue, forKey: languageDefaultsKey)
            } else {
                defaults.removeObject(forKey: languageDefaultsKey)
            }
        }

        let expectedSettingsTitles: [(AppLanguage, String)] = [
            (.chineseSimplified, "界面语言"),
            (.japanese, "表示言語"),
            (.english, "Interface Language")
        ]

        for (language, expectedTitle) in expectedSettingsTitles {
            manager.use(language: language)

            XCTAssertEqual(manager.currentLanguage, language)
            XCTAssertEqual(manager.localized("settings.language"), expectedTitle)
            XCTAssertEqual(defaults.string(forKey: languageDefaultsKey), language.rawValue)
        }
    }

    func testHotCornerLaunchOptionsRemainStable() {
        XCTAssertEqual(
            HotCorner.allCases.map(\.rawValue),
            ["topLeft", "topRight", "bottomLeft", "bottomRight"]
        )
    }

    func testHotCornerPreferenceDefaultsAndRejectsUnknownValues() {
        let defaults = UserDefaults.standard
        let previousValue = defaults.string(forKey: hotCornerDefaultsKey)
        defer {
            if let previousValue {
                defaults.set(previousValue, forKey: hotCornerDefaultsKey)
            } else {
                defaults.removeObject(forKey: hotCornerDefaultsKey)
            }
        }

        defaults.removeObject(forKey: hotCornerDefaultsKey)
        XCTAssertEqual(HotCornerStore.current, .bottomLeft)

        HotCornerStore.current = .topRight
        XCTAssertEqual(defaults.string(forKey: hotCornerDefaultsKey), "topRight")
        XCTAssertEqual(HotCornerStore.current, .topRight)

        defaults.set("center", forKey: hotCornerDefaultsKey)
        XCTAssertEqual(HotCornerStore.current, .bottomLeft)
    }

    func testAppTargetBuildSettingsMatchStoreLaunchPlan() throws {
        let project = try projectFileContents()
        XCTAssertEqual(project.count(of: "PRODUCT_BUNDLE_IDENTIFIER = com.shifeng.peek;"), 2)
        XCTAssertEqual(project.count(of: "PRODUCT_NAME = \"Corner Peek\";"), 2)
        XCTAssertEqual(project.count(of: "PRODUCT_MODULE_NAME = Peek;"), 2)
        XCTAssertEqual(project.count(of: "INFOPLIST_KEY_CFBundleDisplayName = \"Corner Peek\";"), 2)
        XCTAssertEqual(project.count(of: "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"), 2)
        XCTAssertEqual(project.count(of: "INFOPLIST_KEY_LSApplicationCategoryType = \"public.app-category.productivity\";"), 2)
        XCTAssertEqual(project.count(of: "MARKETING_VERSION = 1.0;"), 6)
        XCTAssertEqual(project.count(of: "CURRENT_PROJECT_VERSION = 1;"), 6)
        XCTAssertEqual(project.count(of: "MACOSX_DEPLOYMENT_TARGET = 15.0;"), 4)
    }

    func testLaunchLocalizationDoesNotPromoteUnsupportedFeatures() throws {
        let forbiddenTerms = [
            "Bing",
            "selected text",
            "Selected text",
            "选中文字",
            "選択したテキスト",
            "macOS 14",
            "Sonoma"
        ]

        for language in AppLanguage.allCases {
            let strings = try localizedStrings(for: language)
            let combinedCopy = strings.values.joined(separator: "\n")
            for term in forbiddenTerms {
                XCTAssertFalse(
                    combinedCopy.localizedCaseInsensitiveContains(term),
                    "\(language.rawValue) localization contains unsupported launch copy: \(term)"
                )
            }
        }
    }

    private func localizedStrings(for language: AppLanguage) throws -> [String: String] {
        let lprojPath = try XCTUnwrap(Bundle.main.path(forResource: language.resourceName, ofType: "lproj"))
        let stringsPath = (lprojPath as NSString).appendingPathComponent("Localizable.strings")
        let strings = NSDictionary(contentsOfFile: stringsPath) as? [String: String]
        return try XCTUnwrap(strings, "Could not parse \(language.rawValue) Localizable.strings")
    }

    private func projectFileContents() throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectFile = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("CornerAssistantApp.xcodeproj/project.pbxproj")
        return try String(contentsOf: projectFile, encoding: .utf8)
    }

    private func hotCornerLocalizationKey(for corner: HotCorner) -> String {
        switch corner {
        case .topLeft:
            return "hot_corner.top_left"
        case .topRight:
            return "hot_corner.top_right"
        case .bottomLeft:
            return "hot_corner.bottom_left"
        case .bottomRight:
            return "hot_corner.bottom_right"
        }
    }
}

private extension String {
    func count(of needle: String) -> Int {
        components(separatedBy: needle).count - 1
    }
}
