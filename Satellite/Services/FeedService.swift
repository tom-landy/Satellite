import Foundation
import SwiftData

@MainActor
enum FeedService {
    /// Articles older than this are dropped unless saved, and never added.
    static let keepDays = 30
    /// Feeds fetched at once during a refresh.
    private static let parallel = 6

    static func find(_ feedURL: URL, context: ModelContext) -> Source? {
        // Filtered in memory: URL comparisons in SwiftData predicates are unreliable.
        (try? context.fetch(FetchDescriptor<Source>()))?.first { $0.feedURL == feedURL }
    }

    /// Follows a feed, fetching it first. Returns the existing source if it's already followed.
    @discardableResult
    static func add(_ feedURL: URL, context: ModelContext) async throws -> Source {
        if let existing = find(feedURL, context: context) { return existing }
        let response = try await FeedFetcher.fetch(feedURL)
        guard let feed = response.feed else { throw FeedError.notAFeed }
        let source = Source(feedURL: feedURL, title: feed.title.isEmpty ? (feedURL.host() ?? feedURL.absoluteString) : feed.title)
        context.insert(source)
        apply(response, to: source, context: context)
        source.lastRefreshed = .now
        try context.save()
        return source
    }

    static func refresh(_ source: Source, context: ModelContext) async {
        do {
            let response = try await FeedFetcher.fetch(source.feedURL, etag: source.etag, lastModified: source.lastModified)
            guard source.isAliveSource else { return }
            apply(response, to: source, context: context)
            source.lastError = nil
        } catch {
            guard source.isAliveSource else { return }
            source.lastError = error.localizedDescription
        }
        source.lastRefreshed = .now
    }

    static func refreshAll(context: ModelContext) async {
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        await withTaskGroup(of: Void.self) { group in
            var queue = sources.makeIterator()
            for _ in 0..<parallel {
                guard let source = queue.next() else { break }
                group.addTask { @MainActor in await refresh(source, context: context) }
            }
            while await group.next() != nil {
                guard let source = queue.next() else { continue }
                group.addTask { @MainActor in await refresh(source, context: context) }
            }
        }
        prune(context: context)
        try? context.save()
    }

    static func markAllRead(_ source: Source) {
        for article in source.articles where article.readAt == nil {
            article.readAt = .now
        }
        try? source.modelContext?.save()
    }

    /// Removes a source and its articles, except saved ones, which stay in Saved.
    static func unfollow(_ source: Source, context: ModelContext) {
        for article in source.articles where article.savedAt != nil {
            article.source = nil
        }
        context.delete(source)
        try? context.save()
    }

    private static func apply(_ response: FeedResponse, to source: Source, context: ModelContext) {
        source.etag = response.etag
        source.lastModified = response.lastModified
        guard let feed = response.feed else { return }
        if !feed.title.isEmpty { source.title = feed.title }
        if let site = feed.siteURL { source.siteURL = site }
        if let icon = feed.iconURL { source.iconURL = icon }
        merge(feed.items, into: source, context: context)
    }

    private static func merge(_ items: [ParsedItem], into source: Source, context: ModelContext) {
        let cutoff = Date.now.addingTimeInterval(-Double(keepDays) * 86400)
        let existing = Dictionary(source.articles.map { ($0.itemID, $0) }, uniquingKeysWith: { a, _ in a })
        let prefix = source.feedURL.absoluteString + "#"
        for item in items {
            if let article = existing[item.id] {
                // Posts get edited after publishing; keep the latest text.
                if !item.bodyHTML.isEmpty && article.html != item.bodyHTML {
                    article.html = item.bodyHTML
                    article.excerpt = item.excerpt
                    article.wordCount = item.wordCount
                }
                if !item.title.isEmpty { article.title = item.title }
                continue
            }
            let date = min(item.date ?? .now, .now)
            guard date > cutoff else { continue }
            let article = Article(key: prefix + item.id, itemID: item.id, title: item.title, author: item.author,
                                  date: date, link: item.link, html: item.bodyHTML, excerpt: item.excerpt,
                                  wordCount: item.wordCount, imageURL: item.imageURL, audioURL: item.audioURL)
            context.insert(article)
            article.source = source
        }
    }

    /// Drops old articles nobody saved, so the library doesn't grow forever.
    private static func prune(context: ModelContext) {
        let cutoff = Date.now.addingTimeInterval(-Double(keepDays + 1) * 86400)
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.savedAt == nil && $0.date < cutoff })
        for article in (try? context.fetch(descriptor)) ?? [] {
            context.delete(article)
        }
    }
}

private extension Source {
    /// The source may be unfollowed while its feed is downloading.
    var isAliveSource: Bool { modelContext != nil && !isDeleted }
}
