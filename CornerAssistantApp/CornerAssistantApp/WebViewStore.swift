import SwiftUI
import Combine
import WebKit

@MainActor
final class WebViewStore: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView

    var onTitleChange: ((String) -> Void)?
    var onURLChange: ((URL) -> Void)?
    var onFaviconChange: ((URL) -> Void)?

    private var popupWindows: [ObjectIdentifier: NSWindow] = [:]
    private let slackHostMarker = "slack.com"

    private static let safariUserAgentSuffix = "Version/17.0 Safari/605.1.15"
    private static let aggressiveUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.applicationNameForUserAgent = Self.safariUserAgentSuffix

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.underPageBackgroundColor = .clear
        webView.customUserAgent = Self.aggressiveUserAgent
        normalizeScrollView()
    }

    func load(url: URL) {
        webView.load(URLRequest(url: url))
        onURLChange?(url)
    }

    #if DEBUG
    func loadDebugHTML(_ html: String, baseURL: URL, title: String) {
        webView.loadHTMLString(html, baseURL: baseURL)
        onURLChange?(baseURL)
        onTitleChange?(title)
    }
    #endif

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        normalizeScrollView()
        webView.evaluateJavaScript("window.scrollTo(0,0)", completionHandler: nil)
        onTitleChange?(webView.title ?? "")
        if let url = webView.url {
            onURLChange?(url)
            logSlackDiagnostics(stage: "didFinish", url: url, queryNavigator: true)
        }
        fetchFavicon()
    }
    
    private func fetchFavicon() {
        let script = """
        (function() {
            var icon = document.querySelector('link[rel="icon"]') || document.querySelector('link[rel="shortcut icon"]');
            return icon ? icon.href : null;
        })()
        """
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            if let urlString = result as? String, let url = URL(string: urlString) {
                self?.onFaviconChange?(url)
            }
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let url = webView.url {
            onURLChange?(url)
            logSlackDiagnostics(stage: "didCommit", url: url, queryNavigator: false)
        }
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil,
           shouldOpenInSameView(url: navigationAction.request.url) {
            webView.load(navigationAction.request)
            return nil
        }
        if configuration.applicationNameForUserAgent == nil {
            configuration.applicationNameForUserAgent = Self.safariUserAgentSuffix
        }
        let popupWebView = WKWebView(frame: .zero, configuration: configuration)
        popupWebView.navigationDelegate = self
        popupWebView.uiDelegate = self
        popupWebView.allowsBackForwardNavigationGestures = true
        popupWebView.underPageBackgroundColor = .clear
        popupWebView.customUserAgent = Self.aggressiveUserAgent

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = LocalizationManager.shared.localized("auth.window_title")
        window.center()
        window.contentView = popupWebView
        window.makeKeyAndOrderFront(nil)

        popupWindows[ObjectIdentifier(popupWebView)] = window
        return popupWebView
    }

    func webViewDidClose(_ webView: WKWebView) {
        if let window = popupWindows.removeValue(forKey: ObjectIdentifier(webView)) {
            window.orderOut(nil)
        }
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: LocalizationManager.shared.localized("common.ok"))
        alert.runModal()
        completionHandler()
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: LocalizationManager.shared.localized("common.ok"))
        alert.addButton(withTitle: LocalizationManager.shared.localized("common.cancel"))
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = prompt

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        inputField.stringValue = defaultText ?? ""
        alert.accessoryView = inputField

        alert.addButton(withTitle: LocalizationManager.shared.localized("common.ok"))
        alert.addButton(withTitle: LocalizationManager.shared.localized("common.cancel"))
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            completionHandler(inputField.stringValue)
        } else {
            completionHandler(nil)
        }
    }

    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.prompt)
    }

    // MARK: - Helpers

    private func normalizeScrollView() {
        guard let scrollView = webView.findScrollView() else { return }
        let zeroInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        scrollView.contentInsets = zeroInsets
        scrollView.scrollerInsets = zeroInsets
        scrollView.contentView.contentInsets = zeroInsets
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        if #available(macOS 13.0, *) {
            scrollView.automaticallyAdjustsContentInsets = false
        }
    }

    private func logSlackDiagnostics(stage: String, url: URL, queryNavigator: Bool) {
        guard let host = url.host?.lowercased(), host.contains(slackHostMarker) else { return }
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let customAgent = webView.customUserAgent ?? "nil"
        let appNameAgent = webView.configuration.applicationNameForUserAgent ?? "nil"
        print("[WebView][Slack][\(stage)] url=\(url.absoluteString)")
        print("[WebView][Slack][\(stage)] os=\(osVersion) customUA=\(customAgent) appUA=\(appNameAgent)")
        guard queryNavigator else { return }
        let script = """
        JSON.stringify({
            userAgent: navigator.userAgent,
            platform: navigator.platform,
            appVersion: navigator.appVersion
        })
        """
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("[WebView][Slack][\(stage)] navigator error=\(error.localizedDescription)")
                return
            }
            if let payload = result as? String {
                print("[WebView][Slack][\(stage)] navigator=\(payload)")
            } else {
                print("[WebView][Slack][\(stage)] navigator=unknown")
            }
        }
    }

    private func shouldOpenInSameView(url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host.contains(slackHostMarker)
    }
}

private extension WKWebView {
    func findScrollView() -> NSScrollView? {
        if let scrollView = subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
            return scrollView
        }
        for subview in subviews {
            if let found = subview.firstScrollViewInHierarchy() {
                return found
            }
        }
        return nil
    }
}

private extension NSView {
    func firstScrollViewInHierarchy() -> NSScrollView? {
        if let scrollView = self as? NSScrollView {
            return scrollView
        }
        for subview in subviews {
            if let found = subview.firstScrollViewInHierarchy() {
                return found
            }
        }
        return nil
    }
}
