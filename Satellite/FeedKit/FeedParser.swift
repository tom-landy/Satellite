import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Reads RSS 2.0, RSS 1.0 (RDF), Atom and JSON Feed. Synchronous: call it off the main actor.
enum FeedParser {
    /// `url` is the feed's own address, used to resolve relative links.
    static func parse(_ data: Data, url: URL? = nil) throws -> ParsedFeed {
        var feed = JSONFeed.looksLikeJSON(data) ? try JSONFeed.parse(data) : try XMLFeedParser.parse(data)
        if let url { feed.resolve(against: url) }
        feed.finish()
        return feed
    }
}

extension ParsedFeed {
    mutating func resolve(against base: URL) {
        func fix(_ url: URL?, _ against: URL) -> URL? {
            guard let url else { return nil }
            if url.scheme != nil { return url }
            return URL(string: url.relativeString, relativeTo: against)?.absoluteURL
        }
        siteURL = fix(siteURL, base)
        if siteURL == nil, let scheme = base.scheme, let host = base.host {
            siteURL = URL(string: "\(scheme)://\(host)/")
        }
        iconURL = fix(iconURL, siteURL ?? base)
        for i in items.indices {
            items[i].link = fix(items[i].link, siteURL ?? base)
            let itemBase = items[i].link ?? siteURL ?? base
            items[i].imageURL = fix(items[i].imageURL, itemBase)
            items[i].audioURL = fix(items[i].audioURL, itemBase)
        }
    }

    /// Fills in the fields derived from each item's HTML, and stable ids for items without one.
    mutating func finish() {
        title = title.htmlInlineText
        summary = summary.htmlPlainText
        var seen = Set<String>()
        items = items.compactMap { item in
            var item = item
            item.title = item.title.htmlInlineText
            let text = item.bodyHTML.htmlPlainText
            item.wordCount = HTMLText.wordCount(text)
            item.excerpt = HTMLText.excerpt(fromPlainText: text)
            if item.imageURL == nil {
                item.imageURL = HTMLText.firstImage(in: item.bodyHTML, base: item.link ?? siteURL)
            }
            if item.title.isEmpty {
                item.title = HTMLText.excerpt(fromPlainText: text, limit: 80)
            }
            if item.id.isEmpty {
                item.id = item.link?.absoluteString ?? (item.title + (item.date.map { "\($0.timeIntervalSince1970)" } ?? ""))
            }
            guard !item.id.isEmpty, !(item.title.isEmpty && text.isEmpty), seen.insert(item.id).inserted else { return nil }
            return item
        }
    }
}

private final class XMLFeedParser: NSObject, XMLParserDelegate {
    private enum Kind { case unknown, rss, rdf, atom }

    private var kind = Kind.unknown
    private var feed = ParsedFeed()
    private var item: ParsedItem?
    private var stack: [String] = []
    private var text = ""
    /// Depth of the element whose children are being kept as HTML markup, if any.
    /// Atom's type="xhtml" content arrives as XML elements, and some RSS feeds put
    /// unescaped HTML in descriptions; both are rebuilt into an HTML string.
    private var markupDepth: Int?

    private static let markupContainers: Set<String> = [
        "title", "description", "summary", "content", "content:encoded", "subtitle", "media:description",
    ]
    private static let voidElements: Set<String> = [
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr",
    ]

    static func parse(_ data: Data) throws -> ParsedFeed {
        let delegate = XMLFeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        let ok = parser.parse()
        guard delegate.kind != .unknown else { throw FeedError.notAFeed }
        // A feed that breaks partway (a stray HTML entity, a truncated download) still
        // gives whatever was read before the break.
        if !ok && delegate.feed.items.isEmpty { throw parser.parserError ?? FeedError.notAFeed }
        return delegate.feed
    }

    private var inItem: Bool { item != nil }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        let name = elementName.lowercased()
        if let depth = markupDepth, stack.count >= depth {
            stack.append(name)
            var tag = "<" + elementName
            for (key, value) in attributes.sorted(by: { $0.key < $1.key }) where !key.hasPrefix("xmlns") {
                tag += " \(key)=\"\(value.escapedHTML)\""
            }
            text += tag + ">"
            return
        }
        stack.append(name)
        text = ""

        switch name {
        case "rss":
            kind = .rss
        case "rdf:rdf":
            kind = .rdf
        case "feed":
            if kind == .unknown { kind = .atom }
        case "channel":
            if kind == .unknown { kind = .rss }
        case "item", "entry":
            item = ParsedItem()
            if let about = attributes["rdf:about"] { item?.id = about }
        case "enclosure":
            attach(attributes["url"], type: attributes["type"])
        case "link" where attributes["href"] != nil:
            atomLink(attributes)
        case "media:content":
            let isImage = attributes["medium"] == "image" || (attributes["type"] ?? "").hasPrefix("image/")
                || (attributes["type"] == nil && attributes["medium"] == nil && Self.looksLikeImage(attributes["url"]))
            if isImage { setImage(attributes["url"], preferred: false) }
        case "media:thumbnail":
            setImage(attributes["url"], preferred: false)
        case "itunes:image":
            setImage(attributes["href"] ?? attributes["url"], preferred: false)
        default:
            break
        }

        if Self.markupContainers.contains(name) {
            markupDepth = stack.count
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if let depth = markupDepth, stack.count > depth {
            text += string.escapedHTML
        } else {
            text += string
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        let name = elementName.lowercased()
        if let depth = markupDepth, stack.count > depth {
            stack.removeLast()
            if !Self.voidElements.contains(name) { text += "</\(elementName)>" }
            return
        }
        if markupDepth == stack.count { markupDepth = nil }
        defer {
            stack.removeLast()
            text = ""
        }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = stack.dropLast().last ?? ""

        if var current = item {
            let direct = parent == "item" || parent == "entry"
            switch name {
            case "item", "entry":
                feed.items.append(current)
                item = nil
                return
            case "title" where direct: current.title = value
            case "link" where direct && !value.isEmpty: current.link = Self.url(value)
            case "guid", "id": if direct && !value.isEmpty { current.id = value }
            case "pubdate", "published", "dc:date", "issued":
                if current.published == nil { current.published = FeedDates.parse(value) }
            case "updated", "modified", "atom:updated", "dc:modified":
                current.updated = FeedDates.parse(value)
            case "name" where parent == "author":
                if current.author.isEmpty { current.author = value }
            case "author" where direct && !value.isEmpty && current.author.isEmpty:
                current.author = Self.authorName(value)
            case "dc:creator":
                if current.author.isEmpty { current.author = value }
            case "description", "summary":
                if direct || current.summaryHTML.isEmpty { current.summaryHTML = value }
            case "content:encoded", "content":
                if !value.isEmpty { current.contentHTML = value }
            case "media:description":
                if current.summaryHTML.isEmpty { current.summaryHTML = value }
            default:
                break
            }
            item = current
            return
        }

        let top = parent == "channel" || parent == "feed"
        switch name {
        case "title" where top: feed.title = value
        case "link" where top && !value.isEmpty: if feed.siteURL == nil { feed.siteURL = Self.url(value) }
        case "description", "subtitle", "tagline":
            if top && feed.summary.isEmpty { feed.summary = value }
        case "url" where parent == "image":
            if feed.iconURL == nil { feed.iconURL = Self.url(value) }
        case "icon", "logo":
            if top && feed.iconURL == nil { feed.iconURL = Self.url(value) }
        default:
            break
        }
    }

    // MARK: - Helpers

    private func atomLink(_ attributes: [String: String]) {
        guard let href = attributes["href"] else { return }
        let rel = attributes["rel"] ?? "alternate"
        let type = attributes["type"]
        if item != nil {
            switch rel {
            case "alternate":
                if item?.link == nil || type == "text/html" { item?.link = Self.url(href) }
            case "enclosure":
                attach(href, type: type)
            default:
                break
            }
        } else if rel == "alternate", stack.dropLast().last == "feed" || stack.dropLast().last == "channel" {
            if feed.siteURL == nil || type == "text/html" { feed.siteURL = Self.url(href) }
        }
    }

    private func attach(_ raw: String?, type: String?) {
        guard item != nil, let raw, let url = Self.url(raw) else { return }
        let type = type ?? ""
        if type.hasPrefix("image/") || (type.isEmpty && Self.looksLikeImage(raw)) {
            if item?.imageURL == nil { item?.imageURL = url }
        } else if type.hasPrefix("audio/") {
            item?.audioURL = url
        }
    }

    private func setImage(_ raw: String?, preferred: Bool) {
        guard let raw, let url = Self.url(raw) else { return }
        if item != nil {
            if preferred || item?.imageURL == nil { item?.imageURL = url }
        } else if preferred || feed.iconURL == nil {
            feed.iconURL = url
        }
    }

    private static func looksLikeImage(_ raw: String?) -> Bool {
        guard let path = raw.flatMap({ URL(string: $0) })?.path.lowercased() else { return false }
        return [".jpg", ".jpeg", ".png", ".gif", ".webp", ".avif"].contains { path.hasSuffix($0) }
    }

    static func url(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
            ?? URL(string: trimmed.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")
    }

    /// RSS authors are often "email@example.com (Name)".
    private static func authorName(_ value: String) -> String {
        if let open = value.firstIndex(of: "("), let close = value.lastIndex(of: ")"), open < close {
            return String(value[value.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
        }
        return value
    }
}
