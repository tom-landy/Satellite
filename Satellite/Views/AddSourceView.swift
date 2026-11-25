import SwiftData
import SwiftUI

/// Paste any address: a feed, or a site whose feed Satellite finds.
struct AddSourceView: View {
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var sources: [Source]
    @State private var address = ""
    @State private var found: [DiscoveredFeed] = []
    @State private var searching = false
    @State private var adding: URL?
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Site or feed address", text: $address)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .focused($focused)
                        .onSubmit(find)
                } footer: {
                    Text("For example theverge.com or a blog's address. Satellite finds the feed.")
                }

                if searching {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Looking for a feed…").foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                if !found.isEmpty {
                    Section("Feeds on This Site") {
                        ForEach(found) { feed in
                            Button { add(feed) } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(feed.title).foregroundStyle(.primary)
                                        Text(feed.url.absoluteString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if adding == feed.url {
                                        ProgressView()
                                    } else if isFollowed(feed.url) {
                                        Image(systemName: "checkmark").foregroundStyle(.secondary)
                                    } else {
                                        Image(systemName: "plus.circle.fill").font(.title3)
                                    }
                                }
                            }
                            .disabled(adding != nil || isFollowed(feed.url))
                        }
                    }
                }
            }
            .navigationTitle("Add a Site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Find", action: find)
                        .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty || searching)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func isFollowed(_ url: URL) -> Bool {
        sources.contains { $0.feedURL == url }
    }

    private func find() {
        let input = address
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty, !searching else { return }
        searching = true
        error = nil
        found = []
        Task {
            defer { searching = false }
            do {
                let results = try await FeedDiscovery.discover(input)
                found = results
                // One feed and nothing to choose: follow it straight away.
                if results.count == 1, !isFollowed(results[0].url) { add(results[0]) }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func add(_ feed: DiscoveredFeed) {
        adding = feed.url
        Task {
            defer { adding = nil }
            do {
                try await FeedService.add(feed.url, context: context)
                queue.addNew(context)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
