import SwiftUI
import SwiftData
import UIKit
import PanchangKit

@main
struct PanchangApp: App {
    private let container: ModelContainer = {
        let schema = Schema([SavedLocation.self, Preferences.self, BirthProfile.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    @MainActor
    init() {
        AppChrome.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Palette.accent)
        }
        .modelContainer(container)
    }
}

/// One-time UIKit appearance setup so tab/nav chrome matches the paper +
/// hairline design system instead of the system default background/blue tint.
private enum AppChrome {
    @MainActor
    static func apply() {
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Palette.paper)
        let selected = UIColor(Palette.accent)
        let unselected = UIColor(Palette.inkFaint)
        for itemAppearance in [tabAppearance.stackedLayoutAppearance,
                               tabAppearance.inlineLayoutAppearance,
                               tabAppearance.compactInlineLayoutAppearance] {
            itemAppearance.selected.iconColor = selected
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: selected]
            itemAppearance.normal.iconColor = unselected
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
        }
        tabAppearance.shadowColor = UIColor(Palette.hairline)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Palette.paper)
        navAppearance.shadowColor = UIColor(Palette.hairline)
        let titleFont = UIFont(descriptor: UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
            .withDesign(.serif) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body), size: 0)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Palette.inkStrong), .font: titleFont]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Palette.inkStrong), .font: titleFont]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Palette.accent)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var prefsQuery: [Preferences]

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.horizon") }
            MuhurtaView()
                .tabItem { Label("Muhurta", systemImage: "clock.badge") }
            KundliView()
                .tabItem { Label("Kundli", systemImage: "circle.grid.3x3") }
            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .fullScreenCover(isPresented: Binding(
            get: { prefsQuery.first?.seenOnboarding == false },
            set: { _ in }
        )) {
            if let prefs = prefsQuery.first {
                OnboardingView(seenOnboarding: Binding(
                    get: { prefs.seenOnboarding },
                    set: { prefs.seenOnboarding = $0 }
                ))
            }
        }
        .onAppear {
            ensurePreferences()
            scheduleNotificationsIfEnabled()
        }
        .onChange(of: savedLocations.first(where: { $0.isActive })?.persistentModelID) { _, _ in
            scheduleNotificationsIfEnabled()
        }
        .onChange(of: prefsQuery.first?.calendarPreset) { old, _ in
            // Festival dates shift between traditions; skip the initial nil→value fire.
            if old != nil { scheduleNotificationsIfEnabled() }
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
        let loc = activeLocation; let cfg = activeConfig; let region = prefsQuery.first?.contentRegion
        Task {
            await NotificationScheduler.shared.schedule(
                using: ContentResolver(), location: loc, config: cfg, region: region
            )
        }
    }
}
