import SwiftData
import SwiftUI

/// Brings in sources from another reader's OPML export.
struct ImportView: View {
    /// Set when an .opml file was opened from elsewhere (Files, Mail, AirDrop).
    var file: URL?
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var picking = false
    @State private var total = 0
    @State private var done = 0
    @State private var failed: [String] = []
    @State private var finished = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                if finished {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("Added \(total - failed.count) of \(total)")
                        .font(.title2.bold())
                    if !failed.isEmpty {
                        Text("Couldn't reach \(failed.count): \(failed.prefix(4).joined(separator: ", "))\(failed.count > 4 ? "…" : ""). They're kept in Sources and Satellite tries them again on every check.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                } else if total > 0 {
                    ProgressView(value: Double(done), total: Double(total))
                        .frame(maxWidth: 240)
                    Text("Adding \(done) of \(total)…")
                        .font(.headline)
                        .monospacedDigit()
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Import from Another App")
                        .font(.title2.bold())
                    Text("Export your subscriptions as OPML from your current reader (Feedly, Reeder, NetNewsWire, Inoreader and others all can), then choose the file here.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Choose File") { picking = true }
                        .buttonStyle(.borderedProminent)
                        .foregroundStyle(AccentTheme.onColor)
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(.orange)
                    }
                }
                Spacer()
                Spacer()
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(finished ? "Done" : "Cancel") { dismiss() }
                        .disabled(total > 0 && !finished)
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.opml, .xml, .data]) { result in
                if case .success(let url) = result { run(url) }
            }
            .interactiveDismissDisabled(total > 0 && !finished)
            .task {
                if let file { run(file) }
            }
        }
    }

    private func run(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let feeds = try? OPML.parse(data), !feeds.isEmpty else {
            error = "That file doesn't contain any feeds."
            return
        }
        total = feeds.count
        Task {
            await withTaskGroup(of: (OPMLFeed, Bool).self) { group in
                var pending = feeds.makeIterator()
                for _ in 0..<6 {
                    guard let feed = pending.next() else { break }
                    group.addTask { @MainActor in (feed, await add(feed)) }
                }
                while let result = await group.next() {
                    let (feed, ok) = result
                    done += 1
                    if !ok { failed.append(feed.title) }
                    if let more = pending.next() {
                        group.addTask { @MainActor in (more, await add(more)) }
                    }
                }
            }
            queue.addNew(context)
            finished = true
        }
    }

    /// Follows a feed; if it can't be reached now, keeps it anyway with the OPML's title.
    private func add(_ feed: OPMLFeed) async -> Bool {
        do {
            try await FeedService.add(feed.url, context: context)
            return true
        } catch {
            if FeedService.find(feed.url, context: context) == nil {
                let source = Source(feedURL: feed.url, title: feed.title)
                source.lastError = error.localizedDescription
                context.insert(source)
                try? context.save()
            }
            return false
        }
    }
}
