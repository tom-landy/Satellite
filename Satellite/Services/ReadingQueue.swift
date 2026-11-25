import Foundation
import Observation
import SwiftData

/// One article in the reader, with its key kept separately so the pager can still
/// identify a page after its article has been deleted.
struct ReaderEntry: Identifiable {
    let key: String
    let article: Article
    var id: String { key }
}

/// The reader's run of articles: every unread article from the last few days, newest first,
/// swiped through one at a time. An article is marked read when it's shown and leaves the run
/// when you move on from it, unless you marked it unread again. New articles found by a refresh
/// go straight after the current one.
@MainActor
@Observable
final class ReadingQueue {
    static let windowKey = "unreadWindowDays"
    static let lastRefreshKey = "lastRefreshAll"

    private(set) var entries: [ReaderEntry] = []
    private(set) var index = 0
    /// Bumped when the current pages need drawing again (full text loaded, etc.).
    private(set) var revision = 0
    private(set) var loadingFullText: Set<String> = []
    private(set) var isRefreshing = false
    /// Articles read and gone since the run started, for the progress line.
    private(set) var readThisRun = 0
    var message: String?

    /// How far back unread articles count. Older ones drop out without being marked read,
    /// so a few days away never leaves a pile.
    static var windowDays: Int {
        let days = UserDefaults.standard.integer(forKey: windowKey)
        return days > 0 ? days : 7
    }

    static var lastRefresh: Date? {
        let t = UserDefaults.standard.double(forKey: lastRefreshKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    var current: Article? {
        guard entries.indices.contains(index) else { return nil }
        let article = entries[index].article
        return article.isAlive ? article : nil
    }

    var isAtEnd: Bool { index >= entries.count }

    /// Unread articles left, counting the one on screen.
    var remaining: Int { max(0, entries.count - index) }

    var progress: Double {
        let total = readThisRun + entries.count
        return total == 0 ? 1 : Double(readThisRun + min(index, entries.count)) / Double(total)
    }

    // MARK: - Building the run

    private func unread(_ context: ModelContext) -> [Article] {
        let cutoff = Date.now.addingTimeInterval(-Double(Self.windowDays) * 86400)
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.readAt == nil && $0.date > cutoff },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Starts a fresh run of unread articles. The article on screen stays first, so a rebuild
    /// never pulls the page out from under you.
    func rebuild(_ context: ModelContext) {
        var articles = unread(context)
        if let current {
            articles.removeAll { $0.key == current.key }
            articles.insert(current, at: 0)
        }
        entries = articles.map { ReaderEntry(key: $0.key, article: $0) }
        index = 0
        readThisRun = 0
        revision += 1
        markCurrentRead()
    }

    /// Adds unread articles that aren't in the run yet, straight after the current one.
    func addNew(_ context: ModelContext) {
        dropDeleted()
        let known = Set(entries.map(\.key))
        let fresh = unread(context).filter { !known.contains($0.key) }
        guard !fresh.isEmpty else { return }
        let wasAtEnd = isAtEnd
        let position = wasAtEnd ? entries.count : index + 1
        entries.insert(contentsOf: fresh.map { ReaderEntry(key: $0.key, article: $0) }, at: position)
        if wasAtEnd { markCurrentRead() }
    }

    /// Removes articles whose source was unfollowed.
    func dropDeleted() {
        let currentKey = entries.indices.contains(index) ? entries[index].key : nil
        let before = entries.count
        entries.removeAll { !$0.article.isAlive }
        guard entries.count != before else { return }
        if let currentKey, let i = entries.firstIndex(where: { $0.key == currentKey }) {
            index = i
        } else {
            index = min(index, entries.count)
            markCurrentRead()
        }
    }

    // MARK: - Moving

    /// Called by the pager when a swipe lands on a page.
    func show(_ newIndex: Int) { move(to: newIndex) }

    /// Jumps straight to an article, from the list.
    func jump(to newIndex: Int) { move(to: newIndex) }

    /// Moves to another page. The article being left goes from the run if it's read.
    private func move(to newIndex: Int) {
        var target = min(max(0, newIndex), entries.count)
        guard target != index else { return }
        if entries.indices.contains(index) {
            let leaving = entries[index].article
            if !leaving.isAlive || leaving.readAt != nil {
                entries.remove(at: index)
                if leaving.isAlive { readThisRun += 1 }
                if target > index { target -= 1 }
            }
        }
        index = min(target, entries.count)
        markCurrentRead()
    }

    /// Marks an article other than the current one read, from the list. It goes at once.
    func markRead(at i: Int) {
        guard entries.indices.contains(i), i != index else { return }
        let article = entries[i].article
        if article.isAlive { article.readAt = .now }
        entries.remove(at: i)
        readThisRun += 1
        if i < index { index -= 1 }
    }

    /// Marks every unread article read, including ones older than the unread window.
    func markAllRead(_ context: ModelContext) {
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.readAt == nil })
        let now = Date.now
        for article in (try? context.fetch(descriptor)) ?? [] {
            article.readAt = now
        }
        try? context.save()
        readThisRun += entries.count
        entries = []
        index = 0
        revision += 1
    }

    private func markCurrentRead() {
        guard let article = current else { return }
        if article.readAt == nil { article.readAt = .now }
        if article.source?.alwaysFullText == true && article.fullTextHTML == nil && article.link != nil {
            Task { await loadFullText(article) }
        }
    }

    // MARK: - Actions on an article

    func toggleRead(_ article: Article) {
        article.readAt = article.readAt == nil ? .now : nil
    }

    func toggleSaved(_ article: Article) {
        article.savedAt = article.savedAt == nil ? .now : nil
        try? article.modelContext?.save()
    }

    /// Switches between the feed's text and the full article, fetching it the first time.
    func toggleFullText(_ article: Article) async {
        if article.fullTextHTML != nil {
            article.showsFullText.toggle()
            revision += 1
        } else {
            await loadFullText(article)
        }
    }

    private func loadFullText(_ article: Article) async {
        guard let link = article.link, !loadingFullText.contains(article.key) else { return }
        loadingFullText.insert(article.key)
        defer { loadingFullText.remove(article.key) }
        guard let html = await FullTextLoader.shared.load(link), article.isAlive else {
            if article.isAlive { message = "Couldn't get the full article from \(link.host() ?? "the site")." }
            return
        }
        article.fullTextHTML = html
        article.showsFullText = true
        revision += 1
    }

    // MARK: - Refreshing

    func refresh(_ context: ModelContext) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await FeedService.refreshAll(context: context)
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.lastRefreshKey)
        addNew(context)
    }

    /// Checks feeds if it's been 15 minutes since the last check.
    func refreshIfStale(_ context: ModelContext) async {
        if let last = Self.lastRefresh, last > .now.addingTimeInterval(-15 * 60) { return }
        await refresh(context)
    }
}
