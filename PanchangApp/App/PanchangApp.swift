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
            RootView()
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var prefsQuery: [Preferences]

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.horizon") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .onAppear { ensurePreferences() }
    }

    private func ensurePreferences() {
        if prefsQuery.isEmpty {
            modelContext.insert(Preferences())
        }
    }
}
