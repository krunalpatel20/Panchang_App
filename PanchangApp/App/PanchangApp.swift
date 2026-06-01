import SwiftUI
import SwiftData

@main
struct PanchangApp: App {
    private let container: ModelContainer = {
        let schema = Schema([SavedLocation.self, Preferences.self, CachedDay.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            TodayView()
        }
        .modelContainer(container)
    }
}
