import XCTest
@testable import Peek

final class PinnedSiteTests: XCTestCase {
    func testPinnedSiteIDUsesLowercasedURL() {
        let site = PinnedSite(name: "Docs", url: "https://EXAMPLE.com/Docs")

        XCTAssertEqual(site.id, "https://example.com/docs")
    }

    func testPinnedSiteUsesCustomFaviconWhenProvided() {
        let site = PinnedSite(
            name: "Docs",
            url: "https://example.com",
            customFaviconURL: "https://cdn.example.com/icon.png"
        )

        XCTAssertEqual(site.faviconURL?.absoluteString, "https://cdn.example.com/icon.png")
    }

    func testPinnedSiteFallsBackToGoogleFaviconForHost() {
        let site = PinnedSite(name: "Docs", url: "https://example.com/docs")

        XCTAssertEqual(site.host, "example.com")
        XCTAssertEqual(site.faviconURL?.absoluteString, "https://www.google.com/s2/favicons?domain=example.com&sz=128")
    }

    func testPinnedSiteCodableDerivesIDFromURL() throws {
        let original = PinnedSite(name: "Docs", url: "https://EXAMPLE.com/Docs")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PinnedSite.self, from: data)

        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.url, original.url)
        XCTAssertEqual(decoded.id, "https://example.com/docs")
    }
}
