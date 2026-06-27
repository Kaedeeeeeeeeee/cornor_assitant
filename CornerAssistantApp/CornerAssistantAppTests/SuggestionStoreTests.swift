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
        try await waitForSuggestions(["peek app", "peek browser"], in: store)

        store.clear()
        XCTAssertTrue(store.suggestions.isEmpty)
    }

    func testSuggestionFailureClearsStaleResults() async throws {
        let store = SuggestionStore(provider: ControlledSearchProvider())

        store.update(query: "peek")
        try await waitForSuggestions(["peek app", "peek browser"], in: store)

        ControlledSearchProvider.shouldFail = true
        defer { ControlledSearchProvider.shouldFail = false }

        store.update(query: "offline")
        try await waitForSuggestions([], in: store)
    }

    private func waitForSuggestions(
        _ expected: [String],
        in store: SuggestionStore,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0..<50 {
            if store.suggestions == expected {
                return
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        XCTAssertEqual(store.suggestions, expected, file: file, line: line)
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

private struct ControlledSearchProvider: SearchProvider {
    static var shouldFail = false

    func searchURL(for query: String) -> URL? {
        nil
    }

    func suggestions(for query: String) async throws -> [String] {
        if Self.shouldFail {
            throw URLError(.notConnectedToInternet)
        }
        return ["\(query) app", "\(query) browser"]
    }
}
