import SwiftData
import SwiftUI

enum ReaderSheet: String, Identifiable {
    case sources, settings, addSource, importFeeds
    var id: String { rawValue }
}

/// The whole app, most of the time: one article on screen, swipe left for the next unread one.
struct ReaderView: View {
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme
    @AppStorage(Typeface.storageKey) private var typeface: Typeface = .system
    @AppStorage(ReaderStyle.scaleKey) private var textScale = 1.0
    @Query private var sources: [Source]
    @Binding var sheet: ReaderSheet?
    @State private var safari: IdentifiedURL?

    private var style: ReaderStyle { ReaderStyle(typeface: typeface, textScale: textScale, theme: theme) }

    var body: some View {
        Group {
            if sources.isEmpty {
                EmptySourcesView(sheet: $sheet)
            } else {
                VStack(spacing: 0) {
                    topBar
                    ArticlePager(entries: queue.entries, index: queue.index, endPage: endPage, style: style,
                                 revision: queue.revision,
                                 onIndexChange: { queue.show($0) },
                                 onFullText: { article in Task { await queue.toggleFullText(article) } })
                        .ignoresSafeArea(.container, edges: .horizontal)
                    ArticleActionsBar(article: queue.current) { safari = IdentifiedURL(url: $0) }
                }
            }
        }
        .fullScreenCover(item: $safari) { SafariView(url: $0.url).ignoresSafeArea() }
        .alert(queue.message ?? "", isPresented: Binding(get: { queue.message != nil }, set: { if !$0 { queue.message = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    /// Hosted outside SwiftUI by the pager, so it gets its environment passed explicitly.
    private var endPage: AnyView {
        AnyView(CaughtUpView(sheet: $sheet, sourceCount: sources.count)
            .environment(queue)
            .environment(\.theme, theme)
            .environment(\.modelContext, context)
            .tint(theme.color))
    }

    private var topBar: some View {
        HStack(spacing: 0) {
            BarButton(symbol: "gearshape", label: "Settings") { sheet = .settings }
            Spacer(minLength: 8)
            VStack(spacing: 1) {
                Text(queue.current?.source?.title ?? "Satellite")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.color)
                    .lineLimit(1)
                Text(position)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .animation(.snappy, value: queue.index)
            Spacer(minLength: 8)
            BarButton(symbol: "list.bullet", label: "Sources") { sheet = .sources }
        }
        .padding(.horizontal, 6)
        .frame(height: 48)
        .overlay(alignment: .bottom) {
            ProgressLine(fraction: queue.entries.isEmpty ? 1 : Double(min(queue.index + 1, queue.entries.count)) / Double(queue.entries.count))
        }
    }

    private var position: String {
        if queue.isRefreshing && queue.isAtEnd { return "Checking for new articles…" }
        if queue.isAtEnd { return queue.entries.isEmpty ? "Nothing unread" : "All caught up" }
        return "\(queue.index + 1) of \(queue.entries.count)"
    }
}

struct BarButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .regular))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

/// How far through the run you are: a hairline in the theme colour, as under Orbit's mini player.
struct ProgressLine: View {
    let fraction: Double
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.primary.opacity(0.08))
                Rectangle().fill(theme.color).frame(width: geo.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 2)
        .animation(.easeOut(duration: 0.25), value: fraction)
    }
}

/// Read, save, full text, share and Safari for the article on screen.
struct ArticleActionsBar: View {
    let article: Article?
    let openInSafari: (URL) -> Void
    @Environment(ReadingQueue.self) private var queue

    var body: some View {
        HStack {
            if let article, article.isAlive {
                BarButton(symbol: article.isRead ? "circle" : "circle.inset.filled",
                          label: article.isRead ? "Mark as Unread" : "Mark as Read") {
                    queue.toggleRead(article)
                }
                Spacer()
                BarButton(symbol: article.isSaved ? "bookmark.fill" : "bookmark",
                          label: article.isSaved ? "Remove from Saved" : "Save") {
                    queue.toggleSaved(article)
                }
                .sensoryFeedback(.selection, trigger: article.isSaved)
                Spacer()
                if queue.loadingFullText.contains(article.key) {
                    ProgressView().frame(width: 44, height: 44)
                } else {
                    BarButton(symbol: article.showsFullText ? "doc.plaintext.fill" : "doc.plaintext",
                              label: article.showsFullText ? "Show Feed Version" : "Load Full Article") {
                        Task { await queue.toggleFullText(article) }
                    }
                    .disabled(article.link == nil)
                }
                Spacer()
                if let link = article.link {
                    ShareLink(item: link, subject: Text(article.title)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 19))
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    BarButton(symbol: "safari", label: "Open in Safari") { openInSafari(link) }
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .overlay(alignment: .top) { Divider() }
    }
}

/// The last page of the run.
struct CaughtUpView: View {
    @Binding var sheet: ReaderSheet?
    let sourceCount: Int
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.modelContext) private var context
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            LogoView(theme: theme)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: theme.color.opacity(0.3), radius: 16, y: 5)
            Text("All Caught Up")
                .font(.title2.bold())
            Group {
                if queue.entries.isEmpty {
                    Text("Nothing new from your ^[\(sourceCount) source](inflect: true) in the last \(ReadingQueue.windowDays) days.")
                } else {
                    Text("That's everything new from your ^[\(sourceCount) source](inflect: true). Swipe back to reread.")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            if let last = ReadingQueue.lastRefresh {
                Text("Checked \(Text(last, style: .relative)) ago")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            Button {
                Task { await queue.refresh(context) }
            } label: {
                if queue.isRefreshing {
                    ProgressView().frame(minWidth: 120)
                } else {
                    Text("Check Now").frame(minWidth: 120)
                }
            }
            .buttonStyle(.bordered)
            .disabled(queue.isRefreshing)
            .padding(.top, 4)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

/// First run, or after unfollowing everything.
struct EmptySourcesView: View {
    @Binding var sheet: ReaderSheet?
    @Environment(\.theme) private var theme

    var body: some View {
        ContentUnavailableView {
            LogoView(theme: theme)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.bottom, 8)
            Text("Nothing to Read Yet")
        } description: {
            Text("Add the sites you read. New posts from all of them arrive here, one page at a time.")
        } actions: {
            Button("Add a Site") { sheet = .addSource }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(AccentTheme.onColor)
            Button("Import from Another App") { sheet = .importFeeds }
        }
    }
}

/// The reader opened on a fixed list (Saved, or a source's articles), from a tapped article.
struct StaticReaderView: View {
    let entries: [ReaderEntry]
    @State var index: Int
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @AppStorage(Typeface.storageKey) private var typeface: Typeface = .system
    @AppStorage(ReaderStyle.scaleKey) private var textScale = 1.0
    @State private var safari: IdentifiedURL?

    init(articles: [Article], start: Int) {
        entries = articles.map { ReaderEntry(key: $0.key, article: $0) }
        _index = State(initialValue: start)
    }

    private var current: Article? {
        entries.indices.contains(index) && entries[index].article.isAlive ? entries[index].article : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                Spacer()
                Text("\(index + 1) of \(entries.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 70, height: 44)
            }
            .frame(height: 48)
            .overlay(alignment: .bottom) {
                ProgressLine(fraction: entries.isEmpty ? 1 : Double(index + 1) / Double(entries.count))
            }
            ArticlePager(entries: entries, index: index, endPage: nil,
                         style: ReaderStyle(typeface: typeface, textScale: textScale, theme: theme),
                         revision: queue.revision,
                         onIndexChange: { index = $0; markRead() },
                         onFullText: { article in Task { await queue.toggleFullText(article) } })
                .ignoresSafeArea(.container, edges: .horizontal)
            ArticleActionsBar(article: current) { safari = IdentifiedURL(url: $0) }
        }
        .onAppear(perform: markRead)
        .fullScreenCover(item: $safari) { SafariView(url: $0.url).ignoresSafeArea() }
    }

    private func markRead() {
        if let current, current.readAt == nil { current.readAt = .now }
    }
}
