import SwiftData
import SwiftUI

/// Every unread article on one line each. Tap to read it, swipe to mark it read.
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
            Group {
                if queue.remaining == 0 {
                    ContentUnavailableView("All Caught Up", systemImage: "checkmark.circle",
                                           description: Text("Nothing unread from the last \(ReadingQueue.windowDays) days."))
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
                                    if i != queue.index {
                                        Button { withAnimation { queue.markRead(at: i) } } label: {
                                            Label("Read", systemImage: "checkmark")
                                        }
                                        .tint(theme.color)
                                    }
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
                }
            }
            .navigationTitle(queue.remaining == 0 ? "Unread" : "\(queue.remaining) Unread")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await queue.refresh(context) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Sources") { showsSources = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Mark All as Read") { confirmAll = true }
                        .disabled(queue.remaining == 0)
                }
            }
            .confirmationDialog("Mark everything as read?", isPresented: $confirmAll, titleVisibility: .visible) {
                Button("Mark All as Read", role: .destructive) {
                    queue.markAllRead(context)
                    dismiss()
                }
            } message: {
                Text("Every unread article disappears. Saved articles stay in Saved.")
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
            Text(article.title)
                .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                .foregroundStyle(isCurrent ? theme.color : .primary)
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
