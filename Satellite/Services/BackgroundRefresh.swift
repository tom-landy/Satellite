import BackgroundTasks
import SwiftData

/// Checks feeds while the app is closed, so new articles are waiting when you open Satellite.
/// iOS decides when this actually runs, typically a few times a day.
enum BackgroundRefresh {
    static let identifier = "com.warhound.satellite.refresh"

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = .now.addingTimeInterval(60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    @MainActor
    static func run(_ container: ModelContainer) async {
        schedule()
        await FeedService.refreshAll(context: container.mainContext)
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: ReadingQueue.lastRefreshKey)
    }
}
