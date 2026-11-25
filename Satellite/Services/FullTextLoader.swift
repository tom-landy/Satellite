import Foundation
import WebKit

/// Pulls the article text out of a web page with Mozilla's Readability (ReadabilityScript.swift),
/// the same code behind Firefox's Reader View. Runs entirely on the phone: the page's HTML is
/// downloaded, loaded into an off-screen web view with its own scripts, images and styles blocked,
/// and Readability runs over the result.
@MainActor
final class FullTextLoader: NSObject {
    static let shared = FullTextLoader()

    private var blockRules: WKContentRuleList?
    private var compiledRules = false

    /// A desktop-class Safari user agent; some sites send a stripped page to unknown clients.
    private static let browserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    func load(_ url: URL) async -> String? {
        do {
            var request = URLRequest(url: url, timeoutInterval: 20)
            request.setValue(Self.browserAgent, forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
            let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
            let content = try await extract(html: html, base: response.url ?? url, script: ReadabilityScript.source)
            return content.isEmpty ? nil : content
        } catch {
            return nil
        }
    }

    private func extract(html: String, base: URL, script: String) async throws -> String {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        if let rules = await rules() { config.userContentController.add(rules) }
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        let waiter = LoadWaiter()
        webView.navigationDelegate = waiter
        webView.loadHTMLString(html, baseURL: base)
        try await waiter.wait(seconds: 15)
        // Runs in the app's own script world, which works with the page's scripts turned off.
        let js = script + """

        ;(function () {
            var article = new Readability(document.cloneNode(true)).parse();
            return article && article.content ? article.content : "";
        })();
        """
        let result = try await webView.evaluateJavaScript(js, in: nil, contentWorld: .defaultClient)
        return result as? String ?? ""
    }

    /// Blocks everything but the HTML itself while extracting: Readability only needs the DOM.
    private func rules() async -> WKContentRuleList? {
        if compiledRules { return blockRules }
        compiledRules = true
        let json = """
        [{"trigger": {"url-filter": ".*", "resource-type": ["image", "style-sheet", "script", "font", "media", "raw", "svg-document", "popup"]},
          "action": {"type": "block"}}]
        """
        blockRules = try? await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "satellite.fulltext", encodedContentRuleList: json)
        return blockRules
    }
}

/// Waits for a web view to finish loading, with a time limit.
@MainActor
private final class LoadWaiter: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func wait(seconds: Double) async throws {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                self?.finish(URLError(.timedOut))
            }
        }
    }

    private func finish(_ error: Error?) {
        guard let continuation else { return }
        self.continuation = nil
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { finish(nil) }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(error) }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(error) }
}
