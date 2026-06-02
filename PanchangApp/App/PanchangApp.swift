import SwiftUI
import SwiftData
import PanchangKit

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
        .onAppear {
            ensurePreferences()
            scheduleNotificationsIfEnabled()
        }
        .onChange(of: savedLocations.first(where: { $0.isActive })?.name) { _, _ in
            scheduleNotificationsIfEnabled()
        }
    }

    @Query private var savedLocations: [SavedLocation]

    private var activeLocation: GeoLocation {
        if let loc = savedLocations.first(where: { $0.isActive }) {
            return GeoLocation(latitude: loc.latitude, longitude: loc.longitude,
                               timeZoneIdentifier: loc.timeZoneIdentifier)
        }
        return GeoLocation(latitude: 37.3382, longitude: -121.8863, timeZoneIdentifier: "America/Los_Angeles")
    }

    private var activeConfig: CalendarConfig {
        prefsQuery.first?.calendarPreset == "north_indian" ? .northIndian : .gujaratiWestern
    }

    private func ensurePreferences() {
        if prefsQuery.isEmpty { modelContext.insert(Preferences()) }
    }

    private func scheduleNotificationsIfEnabled() {
        guard prefsQuery.first?.notificationsEnabled == true else { return }
        let loc = activeLocation; let cfg = activeConfig
        Task {
            await NotificationService.shared.scheduleUpcomingFestivals(location: loc, config: cfg)
        }
    }
}
