import SwiftData
import SwiftUI

@main
struct SatelliteApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var queue = ReadingQueue()
    @AppStorage(AccentTheme.storageKey) private var theme: AccentTheme = .standard
    @AppStorage(AppAppearance.storageKey) private var appearance: AppAppearance = .system
    private let container: ModelContainer

    init() {
        let config = ModelConfiguration(isStoredInMemoryOnly: DemoData.isActive)
        do {
            container = try ModelContainer(for: Source.self, Article.self, configurations: config)
        } catch {
            fatalError("Could not open the library: \(error)")
        }
        if DemoData.isActive { DemoData.seed(container.mainContext) }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(queue)
                .environment(\.theme, theme)
                .tint(theme.color)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(container)
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) { [container] in
            await BackgroundRefresh.run(container)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && !DemoData.isActive { BackgroundRefresh.schedule() }
        }
    }
}

struct RootView: View {
    @Environment(ReadingQueue.self) private var queue
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppAppearance.chosenKey) private var appearanceChosen = false
    @State private var sheet: ReaderSheet?
    @State private var importFile: IdentifiedURL?
    @State private var backgroundedAt: Date?

    var body: some View {
        ReaderView(sheet: $sheet)
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .articles: ArticleListView()
                case .sources: SourcesView()
                case .settings: SettingsView()
                case .addSource: AddSourceView()
                case .importFeeds: ImportView()
                }
            }
            .sheet(item: $importFile) { ImportView(file: $0.url) }
            .fullScreenCover(isPresented: Binding(get: { (!appearanceChosen && !DemoData.isActive) || DemoData.showsWelcome },
                                                  set: { _ in })) {
                WelcomeView()
            }
            .onOpenURL { url in
                if url.isFileURL { importFile = IdentifiedURL(url: url) }
            }
            .task {
                if DemoData.isActive {
                    sheet = DemoData.apply(queue: queue, context: context)
                } else {
                    queue.rebuild(context)
                    await queue.refresh(context)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard !DemoData.isActive else { return }
                switch phase {
                case .active:
                    // Back after a while: start a fresh run (what's been read drops out).
                    // Back after a moment: just add anything new, keeping your place.
                    if let away = backgroundedAt, away < .now.addingTimeInterval(-30 * 60) {
                        queue.rebuild(context)
                    } else {
                        queue.addNew(context)
                    }
                    backgroundedAt = nil
                    Task { await queue.refreshIfStale(context) }
                case .background:
                    backgroundedAt = .now
                    try? context.save()
                default:
                    break
                }
            }
    }
}
