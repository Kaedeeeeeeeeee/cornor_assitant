import WebKit
import XCTest
@testable import Peek

@MainActor
final class WebViewStoreTests: XCTestCase {
    func testWebViewConfigurationUsesBrowserCompatibleDefaults() {
        let configuration = WKWebViewConfiguration()

        WebViewPolicy.configure(configuration)

        XCTAssertTrue(configuration.preferences.javaScriptCanOpenWindowsAutomatically)
        XCTAssertEqual(configuration.applicationNameForUserAgent, WebViewPolicy.safariUserAgentSuffix)
        XCTAssertTrue(configuration.applicationNameForUserAgent?.hasPrefix("Version/") == true)
        XCTAssertTrue(configuration.applicationNameForUserAgent?.hasSuffix(" Safari/605.1.15") == true)
    }

    func testSafariUserAgentSuffixUsesInstalledMarketingVersion() {
        XCTAssertEqual(
            WebViewPolicy.safariUserAgentSuffix(for: "27.0"),
            "Version/27.0 Safari/605.1.15"
        )
        XCTAssertEqual(
            WebViewPolicy.safariUserAgentSuffix(for: " 26.1 "),
            "Version/26.1 Safari/605.1.15"
        )
        XCTAssertEqual(
            WebViewPolicy.safariUserAgentSuffix(for: "Safari 27"),
            "Version/26.0 Safari/605.1.15"
        )
    }

    func testWebViewStoreUsesSystemWebKitUserAgentAndDelegates() {
        let store = WebViewStore()

        XCTAssertTrue(store.webView.allowsBackForwardNavigationGestures)
        XCTAssertEqual(store.webView.navigationDelegate as? WebViewStore, store)
        XCTAssertEqual(store.webView.uiDelegate as? WebViewStore, store)
        XCTAssertEqual(store.webView.configuration.applicationNameForUserAgent, WebViewPolicy.safariUserAgentSuffix)
        XCTAssertTrue((store.webView.customUserAgent ?? "").isEmpty)
    }

    func testSlackPopupHostsOpenInSameWebView() {
        XCTAssertTrue(WebViewPolicy.shouldOpenPopupInSameView(url: URL(string: "https://app.slack.com/client/T123")))
        XCTAssertTrue(WebViewPolicy.shouldOpenPopupInSameView(url: URL(string: "https://workspace.slack.com/archives/C123")))

        XCTAssertFalse(WebViewPolicy.shouldOpenPopupInSameView(url: URL(string: "https://accounts.google.com/")))
        XCTAssertFalse(WebViewPolicy.shouldOpenPopupInSameView(url: URL(string: "https://www.notion.so/login")))
        XCTAssertFalse(WebViewPolicy.shouldOpenPopupInSameView(url: nil))
    }
}
