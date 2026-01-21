# Repository Guidelines

## Project Structure & Module Organization
- `CornerAssistantApp/` holds the SwiftUI app source (views, models, managers).
- `CornerAssistantAppTests/` contains unit tests (XCTest).
- `CornerAssistantAppUITests/` contains UI tests (XCTest).
- `CornerAssistantApp.xcodeproj` defines the Xcode project and scheme.
- `CornerAssistantApp/Assets.xcassets` stores app icons and asset catalogs; `CornerAssistantApp/*.lproj` holds localized strings.
- `landing-page/` is a static marketing/support site; `docs/` stores App Store materials.
- `build/` and `*.xcarchive` are build artifacts; do not edit or commit changes there.

## Build, Test, and Development Commands
- `xcodebuild -scheme CornerAssistantApp -destination 'platform=macOS' build` builds the macOS app from the command line.
- `xcodebuild -scheme CornerAssistantApp -destination 'platform=macOS' test` runs unit and UI tests included in the scheme.
- `open CornerAssistantApp.xcodeproj` opens the project in Xcode for debugging and previews.

## Coding Style & Naming Conventions
- Swift 5, 4-space indentation; match existing SwiftUI formatting and spacing.
- Types use UpperCamelCase; methods/properties use lowerCamelCase; enum cases use lowerCamelCase.
- Keep filenames aligned with primary types (e.g., `SlidePanelView.swift`).
- Localized strings live in `*.lproj/Localizable.strings`; update all locales when adding keys.
- No formatter or linter is configured in the repo; keep diffs minimal and consistent with nearby code.

## Testing Guidelines
- Use XCTest in `CornerAssistantAppTests/` and `CornerAssistantAppUITests/`.
- Name test methods with the `test` prefix (e.g., `testLaunch`).
- No explicit coverage target is documented; focus on core UI flows and data handling logic.

## Commit & Pull Request Guidelines
- Recent commits use short type prefixes like `feat:`; keep subjects concise and imperative.
- If changes are user-facing, include a brief rationale in the body or PR description.
- PRs should include a summary, test steps, screenshots for UI changes, and linked issues when applicable.

## Configuration & Release Notes
- App Store copy lives in `docs/AppStore-Materials.md`.
- If you update icons or assets, verify `Assets.xcassets` entries and run a clean build in Xcode.
