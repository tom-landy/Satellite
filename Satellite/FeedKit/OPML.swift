import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct OPMLFeed: Hashable, Sendable {
    let title: String
    let url: URL
}

/// OPML is the subscription-list format every feed reader exports.
enum OPML {
    static func parse(_ data: Data) throws -> [OPMLFeed] {
        let delegate = OPMLParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? FeedError.notAFeed }
        var seen = Set<URL>()
        return delegate.feeds.filter { seen.insert($0.url).inserted }
    }
}

private final class OPMLParser: NSObject, XMLParserDelegate {
    var feeds: [OPMLFeed] = []

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        guard name.lowercased() == "outline" else { return }
        // Apps disagree on attribute case (xmlUrl, xmlURL, xmlurl).
        let attrs = Dictionary(attributes.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { a, _ in a })
        guard let raw = attrs["xmlurl"]?.trimmingCharacters(in: .whitespaces),
              let url = URL(string: raw), url.scheme?.hasPrefix("http") == true else { return }
        feeds.append(OPMLFeed(title: attrs["title"] ?? attrs["text"] ?? url.host() ?? raw, url: url))
    }
}

extension OPML {
    static func export(_ feeds: [(title: String, url: URL)], title: String) -> String {
        let lines = feeds.map {
            "    <outline type=\"rss\" text=\"\($0.title.escapedHTML)\" title=\"\($0.title.escapedHTML)\" xmlUrl=\"\($0.url.absoluteString.escapedHTML)\"/>"
        }
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <opml version="2.0">
          <head><title>\(title.escapedHTML)</title></head>
          <body>
        \(lines.joined(separator: "\n"))
          </body>
        </opml>

        """
    }
}
