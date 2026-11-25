import SafariServices
import SwiftUI
import UIKit
import WebKit

/// Horizontal swiping between articles, one full page each. Built on UIPageViewController so only
/// the page on screen and its neighbours exist at once, however long the run of articles is.
struct ArticlePager: UIViewControllerRepresentable {
    var entries: [ReaderEntry]
    var index: Int
    /// A last page after the articles (the "caught up" page).
    var endPage: AnyView?
    var style: ReaderStyle
    /// Bumped by ReadingQueue when pages need drawing again.
    var revision: Int
    var onIndexChange: (Int) -> Void
    var onFullText: (Article) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal,
                                         options: [.interPageSpacing: 16])
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = .systemBackground
        context.coordinator.keys = entries.map(\.key)
        if let first = context.coordinator.page(at: index) {
            pager.setViewControllers([first], direction: .forward, animated: false)
        }
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        let keys = entries.map(\.key)
        let listChanged = keys != coordinator.keys
        coordinator.keys = keys

        let displayed = pager.viewControllers?.first
        let displayedIndex = displayed.flatMap(coordinator.index(of:))
        if displayed == nil || displayedIndex != index {
            if let page = coordinator.page(at: index) {
                let forward = (displayedIndex ?? 0) <= index
                pager.setViewControllers([page], direction: forward ? .forward : .reverse, animated: false)
            }
        } else if listChanged, let displayed {
            // Articles were added or removed around this page: drop the pager's cached neighbours.
            pager.setViewControllers([displayed], direction: .forward, animated: false)
        }

        if style != coordinator.style || revision != coordinator.revision {
            coordinator.style = style
            coordinator.revision = revision
            for case let page as ArticlePageController in pager.viewControllers ?? [] {
                page.render(style: style)
            }
        }
        if let end = pager.viewControllers?.first as? EndPageController, let endPage {
            end.rootView = endPage
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: ArticlePager
        var keys: [String] = []
        var style: ReaderStyle
        var revision: Int

        init(_ parent: ArticlePager) {
            self.parent = parent
            self.style = parent.style
            self.revision = parent.revision
        }

        func page(at i: Int) -> UIViewController? {
            if parent.entries.indices.contains(i) {
                let entry = parent.entries[i]
                guard entry.article.isAlive else { return nil }
                return ArticlePageController(entry: entry, style: parent.style) { [weak self] article in
                    self?.parent.onFullText(article)
                }
            }
            if i == parent.entries.count, let endPage = parent.endPage {
                return EndPageController(rootView: endPage)
            }
            return nil
        }

        /// Looked up by key rather than stored, so pages stay right when articles are inserted.
        func index(of controller: UIViewController) -> Int? {
            if let page = controller as? ArticlePageController {
                return parent.entries.firstIndex { $0.key == page.key }
            }
            if controller is EndPageController { return parent.entries.count }
            return nil
        }

        func pageViewController(_ pager: UIPageViewController, viewControllerBefore controller: UIViewController) -> UIViewController? {
            guard let i = index(of: controller), i > 0 else { return nil }
            return page(at: i - 1)
        }

        func pageViewController(_ pager: UIPageViewController, viewControllerAfter controller: UIViewController) -> UIViewController? {
            guard let i = index(of: controller) else { return nil }
            return page(at: i + 1)
        }

        func pageViewController(_ pager: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let current = pager.viewControllers?.first, let i = index(of: current) else { return }
            parent.onIndexChange(i)
        }
    }
}

final class EndPageController: UIHostingController<AnyView> {}

/// One article: a web view showing the rendered page. Page scripts are off, links open in Safari.
final class ArticlePageController: UIViewController, WKNavigationDelegate {
    let key: String
    private let article: Article
    private var style: ReaderStyle
    private let onFullText: (Article) -> Void
    private var renderedHTML: String?
    private var webView: WKWebView!

    init(entry: ReaderEntry, style: ReaderStyle, onFullText: @escaping (Article) -> Void) {
        self.key = entry.key
        self.article = entry.article
        self.style = style
        self.onFullText = onFullText
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.dataDetectorTypes = []
        config.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.allowsLinkPreview = true
        view.addSubview(webView)
        render(style: style)
    }

    func render(style: ReaderStyle) {
        self.style = style
        guard isViewLoaded, article.isAlive else { return }
        let html = ArticleRenderer.html(for: article, style: style)
        guard html != renderedHTML else { return }
        renderedHTML = html
        webView.loadHTMLString(html, baseURL: article.link)
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .allow }
        if url.scheme == ArticleRenderer.actionScheme {
            if url.absoluteString.hasSuffix(":fulltext") { onFullText(article) }
            return .cancel
        }
        // The page itself and anything it embeds.
        guard action.navigationType == .linkActivated else { return .allow }
        // Footnotes and other links within the article.
        if let base = article.link, url.fragment != nil,
           url.absoluteString.hasPrefix(base.absoluteString.components(separatedBy: "#")[0] + "#") {
            return .allow
        }
        open(url)
        return .cancel
    }

    private func open(_ url: URL) {
        if url.scheme == "http" || url.scheme == "https" {
            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = UIColor(style.theme.color)
            present(safari, animated: true)
        } else {
            UIApplication.shared.open(url)
        }
    }
}
