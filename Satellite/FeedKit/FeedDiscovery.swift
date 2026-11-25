import Foundation

struct DiscoveredFeed: Hashable, Sendable, Identifiable {
    var url: URL
    var title: String
    var id: URL { url }
}

/// Finds the feed for whatever address someone pastes: a feed itself, a page that
/// declares its feeds, or a site with a feed at one of the usual paths.
enum FeedDiscovery {
    typealias Fetch = (URL) async throws -> (Data, URL)

    static let commonPaths = ["feed", "rss", "feed.xml", "rss.xml", "atom.xml", "index.xml", "feed.json", "blog/feed", "rss/"]

    private static let linkTag = try! NSRegularExpression(pattern: "<link\\b[^>]*>", options: .caseInsensitive)
    private static let attribute = try! NSRegularExpression(
        pattern: "([a-zA-Z_:][-a-zA-Z0-9_:.]*)\\s*=\\s*(?:\"([^\"]*)\"|'([^']*)'|([^\\s\"'>]+))")
    private static let pageTitle = try! NSRegularExpression(pattern: "<title[^>]*>([\\s\\S]*?)</title>", options: .caseInsensitive)
    private static let feedTypes: Set<String> = [
        "application/rss+xml", "application/atom+xml", "application/feed+json",
        "application/json", "application/rdf+xml", "application/xml", "text/xml",
    ]

    /// Turns "example.com" into "https://example.com".
    static func normalise(_ input: String) -> URL? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("feed://") { s = "https://" + s.dropFirst(7) }
        if s.hasPrefix("feed:") { s = String(s.dropFirst(5)) }
        if !s.contains("://") { s = "https://" + s }
        guard let url = URL(string: s), let host = url.host, host.contains(".") || host == "localhost" else { return nil }
        return url
    }

    static func discover(_ input: String, fetch: Fetch = FeedFetcher.fetchPage) async throws -> [DiscoveredFeed] {
        guard let url = normalise(input) else { throw FeedError.badAddress }
        let (data, finalURL) = try await fetch(url)
        if let feed = try? FeedParser.parse(data, url: finalURL), !(feed.title.isEmpty && feed.items.isEmpty) {
            return [DiscoveredFeed(url: finalURL, title: feed.title.isEmpty ? (finalURL.host ?? "") : feed.title)]
        }
        let html = String(decoding: data, as: UTF8.self)
        let declared = links(inHTML: html, base: finalURL)
        if !declared.isEmpty { return declared }

        guard let scheme = finalURL.scheme, let host = finalURL.host,
              let root = URL(string: "\(scheme)://\(host)/") else { throw FeedError.noFeedFound }
        // Try the page's own path first (example.com/blog/feed), then the site root.
        var bases = [root]
        if finalURL.path.count > 1 {
            let dir = finalURL.absoluteString.hasSuffix("/") ? finalURL : finalURL.appendingPathComponent("")
            bases.insert(dir, at: 0)
        }
        for base in bases {
            for path in commonPaths {
                guard let candidate = URL(string: path, relativeTo: base)?.absoluteURL,
                      let (body, resolved) = try? await fetch(candidate),
                      let feed = try? FeedParser.parse(body, url: resolved),
                      !feed.items.isEmpty || !feed.title.isEmpty else { continue }
                return [DiscoveredFeed(url: resolved, title: feed.title.isEmpty ? host : feed.title)]
            }
        }
        throw FeedError.noFeedFound
    }

    /// Feeds a page declares with <link rel="alternate" type="application/rss+xml" href="...">.
    static func links(inHTML html: String, base: URL) -> [DiscoveredFeed] {
        let ns = html as NSString
        let fallbackTitle = pageTitle.firstMatch(in: html, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range(at: 1)).htmlInlineText } ?? (base.host ?? "")
        var found: [DiscoveredFeed] = []
        var seen = Set<URL>()
        for match in linkTag.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let attrs = attributes(of: ns.substring(with: match.range))
            let rel = Set((attrs["rel"] ?? "").lowercased().split(separator: " ").map(String.init))
            let type = (attrs["type"] ?? "").lowercased().trimmingCharacters(in: .whitespaces)
            guard rel.contains("alternate"), feedTypes.contains(type),
                  let href = attrs["href"]?.decodingHTMLEntities.trimmingCharacters(in: .whitespaces), !href.isEmpty,
                  let url = URL(string: href, relativeTo: base)?.absoluteURL else { continue }
            // Many sites label the link just "RSS" or "Feed": the page's title says more.
            let declaredTitle = attrs["title"]?.htmlInlineText ?? ""
            let generic = ["", "rss", "atom", "feed", "rss feed", "atom feed", "json feed", "subscribe"]
            let title = generic.contains(declaredTitle.lowercased()) ? fallbackTitle : declaredTitle
            // WordPress also lists a comments feed. Nobody wants that one.
            if url.path.contains("/comments/") || title.lowercased().contains("comments feed") { continue }
            if seen.insert(url).inserted {
                found.append(DiscoveredFeed(url: url, title: title))
            }
        }
        return found
    }

    private static func attributes(of tag: String) -> [String: String] {
        let ns = tag as NSString
        var out: [String: String] = [:]
        for m in attribute.matches(in: tag, range: NSRange(location: 0, length: ns.length)) {
            let key = ns.substring(with: m.range(at: 1)).lowercased()
            for group in 2...4 where m.range(at: group).location != NSNotFound {
                out[key] = ns.substring(with: m.range(at: group))
                break
            }
        }
        return out
    }
}
