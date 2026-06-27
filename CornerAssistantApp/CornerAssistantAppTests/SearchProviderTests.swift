import XCTest
@testable import Peek

@MainActor
final class SearchProviderTests: XCTestCase {
    private let provider = GoogleSearchProvider()

    func testSearchURLTrimsAndEncodesQuery() throws {
        let url = try XCTUnwrap(provider.searchURL(for: "  mac menu bar browser  "))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.path, "/search")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "q", value: "mac menu bar browser")])
    }

    func testSearchURLRejectsEmptyQuery() {
        XCTAssertNil(provider.searchURL(for: "   "))
    }

    func testSearchURLPreservesUnicodeAndSymbolsAsQueryItem() throws {
        let url = try XCTUnwrap(provider.searchURL(for: "  Peek 日本語 & macOS  "))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))

        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "q", value: "Peek 日本語 & macOS")])
    }

    func testNormalizedURLKeepsExplicitHTTPSURL() {
        let url = provider.normalizedURL(from: "https://example.com/docs?tab=peek")

        XCTAssertEqual(url?.absoluteString, "https://example.com/docs?tab=peek")
    }

    func testNormalizedURLKeepsExplicitHTTPURL() {
        let url = provider.normalizedURL(from: "http://example.com/docs")

        XCTAssertEqual(url?.absoluteString, "http://example.com/docs")
    }

    func testNormalizedURLAddsHTTPSForHostLikeInput() {
        let url = provider.normalizedURL(from: "example.com")

        XCTAssertEqual(url?.absoluteString, "https://example.com")
    }

    func testNormalizedURLTrimsHostLikeInput() {
        let url = provider.normalizedURL(from: "  example.com/docs  ")

        XCTAssertEqual(url?.absoluteString, "https://example.com/docs")
    }

    func testNormalizedURLAllowsLocalhost() {
        let url = provider.normalizedURL(from: "localhost")

        XCTAssertEqual(url?.absoluteString, "https://localhost")
    }

    func testNormalizedURLRejectsPlainSearchTerms() {
        XCTAssertNil(provider.normalizedURL(from: "menu bar browser"))
        XCTAssertNil(provider.normalizedURL(from: "peek"))
    }
}
