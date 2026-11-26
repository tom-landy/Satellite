import SwiftData
import SwiftUI

/// Every article in the reader's view (Today, Yesterday or This Week) on one line each, unread in
/// full colour and read ones dimmed. Tap to read it, swipe to mark it read or unread, or save it.
/// Opened from the list button in the reader.
struct ArticleListView: View {
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showsSources = false
    @State private var confirmAll = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Show", selection: Binding(get: { queue.scope }, set: { queue.setScope($0, context) })) {
                    ForEach(ReaderScope.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                if queue.entries.isEmpty {
                    ContentUnavailableView("Nothing Here", systemImage: "tray",
                                           description: Text("No articles \(queue.scope.phrase)."))
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(Array(queue.entries.enumerated()), id: \.element.key) { i, entry in
                            if entry.article.isAlive {
                                Button {
                                    queue.jump(to: i)
                                    dismiss()
                                } label: {
                                    ArticleLine(article: entry.article, isCurrent: i == queue.index)
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .swipeActions(edge: .leading) {
                                    Button { queue.toggleRead(at: i) } label: {
                                        Label(entry.article.isRead ? "Unread" : "Read",
                                              systemImage: entry.article.isRead ? "circle.inset.filled" : "checkmark")
                                    }
                                    .tint(theme.color)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button { queue.toggleSaved(entry.article) } label: {
                                        Label(entry.article.isSaved ? "Unsave" : "Save",
                                              systemImage: entry.article.isSaved ? "bookmark.slash" : "bookmark")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 44)
                    .refreshable { await queue.refresh(context) }
                }
            }
            .navigationTitle(queue.unreadCount == 0 ? queue.scope.name : "\(queue.scope.name) · \(queue.unreadCount) Unread")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sources") { showsSources = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Mark All as Read") { confirmAll = true }
                        .disabled(queue.unreadCount == 0)
                }
            }
            .confirmationDialog("Mark everything as read?", isPresented: $confirmAll, titleVisibility: .visible) {
                Button("Mark All as Read", role: .destructive) {
                    queue.markAllRead(context)
                    dismiss()
                }
            } message: {
                Text("Every unread article is marked read, in every view. You can still swipe back to them.")
            }
            .sheet(isPresented: $showsSources) { SourcesView() }
        }
    }
}

/// One line: source icon, title, how long ago.
struct ArticleLine: View {
    let article: Article
    var isCurrent = false
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            SourceIcon(source: article.source, size: 20)
                .opacity(article.isRead && !isCurrent ? 0.5 : 1)
            Text(article.title)
                .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? theme.color : (article.isRead ? .secondary : .primary))
                .lineLimit(1)
            Spacer(minLength: 6)
            if article.isSaved {
                Image(systemName: "bookmark.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(article.date.shortAge)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isCurrent ? "On screen now" : "")
    }
}

extension Date {
    /// "now", "12m", "3h", "2d".
    var shortAge: String {
        let seconds = max(0, Date.now.timeIntervalSince(self))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        if seconds < 86400 { return "\(Int(seconds / 3600))h" }
        return "\(Int(seconds / 86400))d"
    }
}
