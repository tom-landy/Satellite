import Foundation

/// JSON Feed 1.0 and 1.1 (jsonfeed.org).
enum JSONFeed {
    static func looksLikeJSON(_ data: Data) -> Bool {
        for byte in data.prefix(64) {
            switch byte {
            case 0xEF, 0xBB, 0xBF, 0x20, 0x09, 0x0A, 0x0D: continue
            case UInt8(ascii: "{"): return true
            default: return false
            }
        }
        return false
    }

    static func parse(_ data: Data) throws -> ParsedFeed {
        guard let doc = try? JSONDecoder().decode(Document.self, from: data),
              doc.version?.contains("jsonfeed") == true else { throw FeedError.notAFeed }
        var feed = ParsedFeed()
        feed.title = doc.title ?? ""
        feed.siteURL = doc.home_page_url.flatMap(URL.init(string:))
        feed.summary = doc.description ?? ""
        feed.iconURL = (doc.icon ?? doc.favicon).flatMap(URL.init(string:))
        let feedAuthor = doc.authors?.first?.name ?? doc.author?.name ?? ""
        feed.items = (doc.items ?? []).map { entry in
            var item = ParsedItem()
            item.id = entry.id?.value ?? ""
            item.title = entry.title ?? ""
            item.link = (entry.url ?? entry.external_url).flatMap(URL.init(string:))
            item.author = entry.authors?.first?.name ?? entry.author?.name ?? feedAuthor
            item.published = entry.date_published.flatMap(FeedDates.parse)
            item.updated = entry.date_modified.flatMap(FeedDates.parse)
            if let html = entry.content_html, !html.isEmpty {
                item.contentHTML = html
            } else if let text = entry.content_text, !text.isEmpty {
                item.contentHTML = text.escapedHTML
                    .components(separatedBy: "\n\n")
                    .map { "<p>" + $0.replacingOccurrences(of: "\n", with: "<br>") + "</p>" }
                    .joined()
            }
            item.summaryHTML = entry.summary?.escapedHTML ?? ""
            item.imageURL = (entry.image ?? entry.banner_image).flatMap(URL.init(string:))
            item.audioURL = entry.attachments?.first { $0.mime_type?.hasPrefix("audio/") == true }
                .flatMap { URL(string: $0.url) }
            return item
        }
        return feed
    }

    // Field names match the spec, hence the snake case.
    private struct Document: Decodable {
        var version: String?
        var title: String?
        var home_page_url: String?
        var description: String?
        var icon: String?
        var favicon: String?
        var author: Author?
        var authors: [Author]?
        var items: [Item]?
    }

    private struct Item: Decodable {
        var id: LooseString?
        var url: String?
        var external_url: String?
        var title: String?
        var content_html: String?
        var content_text: String?
        var summary: String?
        var image: String?
        var banner_image: String?
        var date_published: String?
        var date_modified: String?
        var author: Author?
        var authors: [Author]?
        var attachments: [Attachment]?
    }

    private struct Author: Decodable {
        var name: String?
    }

    private struct Attachment: Decodable {
        var url: String
        var mime_type: String?
    }

    /// Some feeds use numbers for ids, which the spec says should be strings.
    private struct LooseString: Decodable {
        var value: String
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let s = try? c.decode(String.self) {
                value = s
            } else if let i = try? c.decode(Int.self) {
                value = String(i)
            } else {
                value = String(try c.decode(Double.self))
            }
        }
    }
}
