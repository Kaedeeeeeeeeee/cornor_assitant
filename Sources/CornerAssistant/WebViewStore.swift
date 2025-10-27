import SwiftUI
import WebKit

@MainActor
final class WebViewStore: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView

    var onTitleChange: ((String) -> Void)?
    var onURLChange: ((URL) -> Void)?

    override init() {
        webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        normalizeScrollView()
    }

    func load(url: URL) {
        webView.load(URLRequest(url: url))
        onURLChange?(url)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        normalizeScrollView()
        webView.evaluateJavaScript("window.scrollTo(0,0)", completionHandler: nil)
        onTitleChange?(webView.title ?? "")
        if let url = webView.url {
            onURLChange?(url)
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let url = webView.url {
            onURLChange?(url)
        }
    }

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
}

extension WKWebView {
    fileprivate func findScrollView() -> NSScrollView? {
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
