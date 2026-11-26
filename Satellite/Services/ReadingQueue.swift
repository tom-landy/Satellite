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

/// Which articles the reader swipes through.
enum ReaderScope: String, CaseIterable, Identifiable {
    case today, yesterday, week

    static let storageKey = "readerScope"
    var id: String { rawValue }

    var name: String {
        switch self {
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .week: "This Week"
        }
    }

    /// "from today", for sentences.
    var phrase: String {
        switch self {
        case .today: "from today"
        case .yesterday: "from yesterday"
        case .week: "from the last 7 days"
        }
    }

    /// Start (inclusive) and end (exclusive). This Week is the last 7 days including today,
    /// so it's never nearly empty on a Monday morning.
    var range: (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let farFuture = Date.distantFuture
        switch self {
        case .today: return (today, farFuture)
        case .yesterday: return (calendar.date(byAdding: .day, value: -1, to: today)!, today)
        case .week: return (calendar.date(byAdding: .day, value: -6, to: today)!, farFuture)
        }
    }
}

/// The reader's run of articles: everything from today, yesterday or the last 7 days, newest
/// first, read or not, swiped through one at a time. It opens at the first unread article, marks
/// articles read as they're shown, and keeps them in place so swiping back always works. New
/// articles found by a refresh go straight after the current one.
@MainActor
@Observable
final class ReadingQueue {
    static let lastRefreshKey = "lastRefreshAll"

    private(set) var entries: [ReaderEntry] = []
    private(set) var index = 0
    /// Bumped when the current pages need drawing again (full text loaded, etc.).
    private(set) var revision = 0
    private(set) var loadingFullText: Set<String> = []
    private(set) var isRefreshing = false
    private(set) var scope: ReaderScope =
        ReaderScope(rawValue: UserDefaults.standard.string(forKey: ReaderScope.storageKey) ?? "") ?? .today
    var message: String?

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

    /// Unread articles after the one on screen: what's still to come.
    var toGo: Int {
        guard index + 1 < entries.count else { return 0 }
        return entries[(index + 1)...].filter { $0.article.isAlive && $0.article.readAt == nil }.count
    }

    /// Unread articles anywhere in the run, including before the current one.
    var unreadCount: Int {
        entries.filter { $0.article.isAlive && $0.article.readAt == nil }.count
    }

    /// Share of the run that's read, for the progress line.
    var progress: Double {
        guard !entries.isEmpty else { return 1 }
        return Double(entries.count - unreadCount) / Double(entries.count)
    }

    // MARK: - Building the run

    private func articles(in scope: ReaderScope, _ context: ModelContext) -> [Article] {
        let (start, end) = scope.range
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Unread articles in another view, for the caught-up page's suggestions.
    func unreadCount(in scope: ReaderScope, _ context: ModelContext) -> Int {
        let (start, end) = scope.range
        let descriptor = FetchDescriptor<Article>(
            predicate: #Predicate { $0.readAt == nil && $0.date >= start && $0.date < end })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Loads the run afresh and opens it at the first unread article (the caught-up page if
    /// there isn't one). With `keepPlace`, the article on screen stays on screen if it's still
    /// in the run, so a rebuild never pulls the page out from under you.
    func rebuild(_ context: ModelContext, keepPlace: Bool = true) {
        let currentKey = keepPlace ? current?.key : nil
        let articles = articles(in: scope, context)
        entries = articles.map { ReaderEntry(key: $0.key, article: $0) }
        if let currentKey, let i = entries.firstIndex(where: { $0.key == currentKey }) {
            index = i
        } else {
            index = entries.firstIndex { $0.article.readAt == nil } ?? entries.count
        }
        revision += 1
        markCurrentRead()
    }

    func setScope(_ newScope: ReaderScope, _ context: ModelContext) {
        guard newScope != scope else { return }
        scope = newScope
        UserDefaults.standard.set(newScope.rawValue, forKey: ReaderScope.storageKey)
        rebuild(context, keepPlace: false)
    }

    /// Adds articles that aren't in the run yet, straight after the current one.
    func addNew(_ context: ModelContext) {
        dropDeleted()
        let known = Set(entries.map(\.key))
        let fresh = articles(in: scope, context).filter { !known.contains($0.key) }
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
    func show(_ newIndex: Int) { jump(to: newIndex) }

    /// Goes straight to a page, from a swipe or the list.
    func jump(to newIndex: Int) {
        let target = min(max(0, newIndex), entries.count)
        guard target != index else { return }
        index = target
        markCurrentRead()
    }

    /// Marks an article read or unread from the list.
    func toggleRead(at i: Int) {
        guard entries.indices.contains(i), entries[i].article.isAlive else { return }
        toggleRead(entries[i].article)
    }

    /// Marks every unread article read, in every view. The run stays, so you can still swipe back.
    func markAllRead(_ context: ModelContext) {
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate { $0.readAt == nil })
        let now = Date.now
        for article in (try? context.fetch(descriptor)) ?? [] {
            article.readAt = now
        }
        try? context.save()
        index = entries.count
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
