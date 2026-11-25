import SwiftData
import SwiftUI

/// Everything you follow, plus Saved. Opened from the list button in the reader.
struct SourcesView: View {
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Source.title) private var sources: [Source]
    @Query(filter: #Predicate<Article> { $0.savedAt != nil }) private var saved: [Article]
    @State private var showsAdd = false
    @State private var showsImport = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        SavedView()
                    } label: {
                        Label("Saved", systemImage: "bookmark")
                            .badge(saved.count)
                    }
                }
                Section {
                    ForEach(sources) { source in
                        NavigationLink(value: source) { SourceRow(source: source) }
                    }
                    .onDelete { offsets in
                        for i in offsets { FeedService.unfollow(sources[i], context: context) }
                        queue.dropDeleted()
                    }
                } header: {
                    Text("Following")
                } footer: {
                    if let last = ReadingQueue.lastRefresh {
                        Text("Checked \(Text(last, style: .relative)) ago. Pull down to check now.")
                    }
                }
            }
            .navigationDestination(for: Source.self) { SourceDetailView(source: $0) }
            .navigationTitle("Sources")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await queue.refresh(context) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button {
                            showsImport = true
                        } label: {
                            Label("Import from Another App", systemImage: "square.and.arrow.down")
                        }
                        if let exportURL, !sources.isEmpty {
                            ShareLink(item: exportURL) {
                                Label("Export \(sources.count) Sources (OPML)", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button { showsAdd = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add a Site")
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showsAdd) { AddSourceView() }
            .sheet(isPresented: $showsImport) { ImportView() }
            .task(id: sources.count) { exportURL = OPML.exportFile(sources) }
        }
    }
}

struct SourceRow: View {
    let source: Source

    var body: some View {
        HStack(spacing: 12) {
            SourceIcon(source: source, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                    .lineLimit(1)
                if let error = source.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else {
                    Text(source.host)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct SourceDetailView: View {
    @Bindable var source: Source
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var confirmUnfollow = false
    @State private var opened: Int?

    private var recent: [Article] { Array(source.recentArticles.prefix(20)) }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    SourceIcon(source: source, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(source.title).font(.headline)
                        Text(source.host).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if let error = source.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } footer: {
                    Text("Satellite keeps trying each time it checks for new articles.")
                }
            }

            Section {
                Toggle("Always Load Full Article", isOn: $source.alwaysFullText)
            } footer: {
                Text("For sites whose feed only has a summary. Satellite fetches each article's web page and keeps just the text.")
            }

            if !recent.isEmpty {
                Section("Recent") {
                    ForEach(Array(recent.enumerated()), id: \.element.key) { i, article in
                        Button { opened = i } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(article.title)
                                    .font(.subheadline.weight(article.isRead ? .regular : .semibold))
                                    .foregroundStyle(article.isRead ? .secondary : .primary)
                                    .lineLimit(2)
                                Text(article.date.articleDate)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Mark All as Read") { FeedService.markAllRead(source) }
                if let site = source.siteURL {
                    Button("Open Website") { openURL(site) }
                }
                Button("Unfollow", role: .destructive) { confirmUnfollow = true }
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.feedURL.absoluteString).textSelection(.enabled)
                    if let last = source.lastRefreshed {
                        Text("Checked \(Text(last, style: .relative)) ago")
                    }
                }
            }
        }
        .navigationTitle(source.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Unfollow \(source.title)?", isPresented: $confirmUnfollow, titleVisibility: .visible) {
            Button("Unfollow", role: .destructive) {
                // Leave this page before deleting what it shows.
                let source = source
                dismiss()
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    FeedService.unfollow(source, context: context)
                    queue.dropDeleted()
                }
            }
        } message: {
            Text("Its articles are removed too, apart from any you've saved.")
        }
        .fullScreenCover(item: Binding(get: { opened.map { OpenedIndex(value: $0) } }, set: { opened = $0?.value })) { item in
            StaticReaderView(articles: recent, start: item.value)
        }
    }
}

struct OpenedIndex: Identifiable {
    let value: Int
    var id: Int { value }
}

struct SavedView: View {
    @Query(filter: #Predicate<Article> { $0.savedAt != nil }, sort: [SortDescriptor(\Article.savedAt, order: .reverse)])
    private var saved: [Article]
    @State private var opened: Int?

    var body: some View {
        Group {
            if saved.isEmpty {
                ContentUnavailableView("Nothing Saved", systemImage: "bookmark",
                                       description: Text("Tap the bookmark under an article to keep it here."))
            } else {
                List {
                    ForEach(Array(saved.enumerated()), id: \.element.key) { i, article in
                        Button { opened = i } label: {
                            HStack(alignment: .top, spacing: 12) {
                                SourceIcon(source: article.source, size: 28)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(article.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text([article.source?.title, article.date.articleDate].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button("Remove", role: .destructive) { article.savedAt = nil }
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: Binding(get: { opened.map { OpenedIndex(value: $0) } }, set: { opened = $0?.value })) { item in
            StaticReaderView(articles: saved, start: item.value)
        }
    }
}
