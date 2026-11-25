import Foundation
import SwiftData

@Model
final class Article {
    /// Feed URL + item id, so ids that repeat across feeds don't collide.
    @Attribute(.unique) var key: String
    var itemID: String
    var title: String
    var author: String
    /// Published date, never later than when it was first seen.
    var date: Date
    var link: URL?
    /// The feed's HTML for the article: its full content when the feed has it, else the summary.
    var html: String
    var excerpt: String
    var wordCount: Int
    var imageURL: URL?
    var audioURL: URL?
    var firstSeen: Date
    /// When it was shown in the reader. nil means unread.
    var readAt: Date?
    var savedAt: Date?
    /// Text pulled from the article's web page, for feeds that only give a summary.
    var fullTextHTML: String?
    var showsFullText: Bool = false
    var source: Source?

    init(key: String, itemID: String, title: String, author: String, date: Date, link: URL?,
         html: String, excerpt: String, wordCount: Int, imageURL: URL?, audioURL: URL?) {
        self.key = key
        self.itemID = itemID
        self.title = title
        self.author = author
        self.date = date
        self.link = link
        self.html = html
        self.excerpt = excerpt
        self.wordCount = wordCount
        self.imageURL = imageURL
        self.audioURL = audioURL
        self.firstSeen = .now
    }

    var isRead: Bool { readAt != nil }
    var isSaved: Bool { savedAt != nil }

    /// The feed only gave a teaser, so the full article is worth fetching.
    var isTeaser: Bool { wordCount < 120 && link != nil }

    var readingMinutes: Int { max(1, Int((Double(wordCount) / 230).rounded())) }

    var bodyHTML: String {
        if showsFullText, let fullTextHTML { return fullTextHTML }
        return html
    }

    /// Safe to touch: deleted articles (an unfollowed source) must not be read.
    var isAlive: Bool { modelContext != nil && !isDeleted }
}
