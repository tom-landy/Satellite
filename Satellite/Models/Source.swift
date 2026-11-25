import Foundation
import SwiftData

/// A site you follow, by its feed.
@Model
final class Source {
    @Attribute(.unique) var feedURL: URL
    var title: String
    var siteURL: URL?
    var iconURL: URL?
    var addedAt: Date
    var lastRefreshed: Date?
    /// Why the last refresh failed; nil when it worked.
    var lastError: String?
    /// HTTP validators from the last fetch, so unchanged feeds come back as "not modified".
    var etag: String?
    var lastModified: String?
    /// For feeds that only carry a summary: fetch each article's page and pull out the text.
    var alwaysFullText: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Article.source)
    var articles: [Article] = []

    init(feedURL: URL, title: String) {
        self.feedURL = feedURL
        self.title = title
        self.addedAt = .now
    }

    var host: String {
        (siteURL ?? feedURL).host()?.replacingOccurrences(of: "www.", with: "") ?? feedURL.absoluteString
    }

    var recentArticles: [Article] {
        articles.sorted { $0.date > $1.date }
    }
}
