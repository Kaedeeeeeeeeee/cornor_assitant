import WebKit
import XCTest
@testable import Peek

@MainActor
final class WebViewStoreTests: XCTestCase {
    func testWebViewConfigurationUsesBrowserCompatibleDefaults() {
        let configuration = WKWebViewConfiguration()

        WebViewPolicy.configure(configuration)

        XCTAssertTrue(configuration.preferences.javaScriptCanOpenWindowsAutomatically)
        XCTAssertEqual(configuration.applicationNameForUserAgent, "Version/17.0 Safari/605.1.15")
    }

    func testWebViewStoreUsesSafariLikeUserAgentAndDelegates() {
        let store = WebViewStore()

        XCTAssertTrue(store.webView.allowsBackForwardNavigationGestures)
        XCTAssertEqual(store.webView.navigationDelegate as? WebViewStore, store)
        XCTAssertEqual(store.webView.uiDelegate as? WebViewStore, store)
        XCTAssertEqual(store.webView.configuration.applicationNameForUserAgent, WebViewPolicy.safariUserAgentSuffix)
        XCTAssertEqual(store.webView.customUserAgent, WebViewPolicy.browserUserAgent)
        XCTAssertTrue(WebViewPolicy.browserUserAgent.contains("Mac OS X 15_0"))
        XCTAssertTrue(WebViewPolicy.browserUserAgent.contains("Safari/605.1.15"))
    }

    func testSlackPopupHostsOpenInSameWebView() {
        XCTAssertTrue(WebViewPolicy.shouldOpenPopupInSameView(url: URL(string: "https://app.slack.com/client/T123")))
        XCTAssertTrue(WebViewPolicy.shouldOpenPopupInSameView(url: URL(string: "https://workspace.slack.com/archives/C123")))

        XCTAssertFalse(WebViewPolicy.shouldOpenPopupInSameView(url: URL(string: "https://accounts.google.com/")))
        XCTAssertFalse(WebViewPolicy.shouldOpenPopupInSameView(url: URL(string: "https://www.notion.so/login")))
        XCTAssertFalse(WebViewPolicy.shouldOpenPopupInSameView(url: nil))
    }
}
