import XCTest
@testable import Peek

@MainActor
final class SuggestionStoreTests: XCTestCase {
    func testSuggestionsRequireMinimumQueryLength() {
        let store = SuggestionStore(provider: StubSearchProvider())

        store.update(query: "p")

        XCTAssertTrue(store.suggestions.isEmpty)
    }

    func testSuggestionsDebounceAndClear() async throws {
        let store = SuggestionStore(provider: StubSearchProvider())

        store.update(query: "peek")
        try await Task.sleep(nanoseconds: 320_000_000)

        XCTAssertEqual(store.suggestions, ["peek app", "peek browser"])

        store.clear()
        XCTAssertTrue(store.suggestions.isEmpty)
    }
}

private struct StubSearchProvider: SearchProvider {
    func searchURL(for query: String) -> URL? {
        nil
    }

    func suggestions(for query: String) async throws -> [String] {
        ["\(query) app", "\(query) browser"]
    }
}
