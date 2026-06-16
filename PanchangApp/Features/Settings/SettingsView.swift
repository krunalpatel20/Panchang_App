import SwiftUI
import SwiftData
import PanchangKit

struct SettingsView: View {
    @Query private var savedLocations: [SavedLocation]
    @Query private var prefsQuery: [Preferences]

    @State private var showLocationSearch = false

    private var prefs: Preferences {
        if let p = prefsQuery.first { return p }
        let p = Preferences()
        return p
    }

    private var activeLocation: SavedLocation? {
        savedLocations.first { $0.isActive }
    }

    /// Same fallback as RootView so scheduling from here matches what the app displays.
    private var activeGeoLocation: GeoLocation {
        if let loc = activeLocation {
            return GeoLocation(latitude: loc.latitude, longitude: loc.longitude,
                               timeZoneIdentifier: loc.timeZoneIdentifier)
        }
        return GeoLocation(latitude: 37.3382, longitude: -121.8863, timeZoneIdentifier: "America/Los_Angeles")
    }

    private var activeConfig: CalendarConfig {
        prefs.calendarPreset == "north_indian" ? .northIndian : .gujaratiWestern
    }

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                calendarSection
                regionSection
                janmaSection
                kundliSection
                scriptSection
                notificationsSection
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView()
            }
        }
    }

    private var locationSection: some View {
        Section {
            Button {
                showLocationSearch = true
            } label: {
                HStack {
                    Label("Location", systemImage: "location")
                    Spacer()
                    Text(activeLocation?.name ?? "San Jose, CA")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .foregroundStyle(.primary)
        } footer: {
            Text("Used for sunrise/sunset and muhurta calculations.")
        }
    }

    private var calendarSection: some View {
        Section {
            Picker("Tradition", selection: Binding(
                get: { prefs.calendarPreset },
                set: { prefs.calendarPreset = $0 }
            )) {
                Text("Gujarati / Western").tag("gujarati_western")
                Text("North Indian (Purnimanta)").tag("north_indian")
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Calendar Tradition")
        } footer: {
            Text("Affects month naming and Vikram Samvat year for Gujarat dates.")
        }
    }

    private var regionSection: some View {
        Section {
            Picker("Region", selection: Binding(
                get: { prefs.contentRegion ?? "none" },
                set: { prefs.contentRegion = $0 == "none" ? nil : $0 }
            )) {
                Text("None").tag("none")
                Text("Gujarati").tag("gujarati")
                Text("Jain").tag("jain")
                Text("Sikh").tag("sikh")
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Regional Content")
        } footer: {
            Text("Shows region-specific festivals alongside the main calendar.")
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { prefs.notificationsEnabled },
                set: { newValue in
                    prefs.notificationsEnabled = newValue
                    let loc = activeGeoLocation; let cfg = activeConfig; let region = prefs.contentRegion
                    if newValue {
                        Task {
                            let granted = await NotificationScheduler.shared.requestPermission()
                            if granted {
                                await NotificationScheduler.shared.schedule(
                                    using: ContentResolver(), location: loc, config: cfg, region: region
                                )
                            } else {
                                await MainActor.run { prefs.notificationsEnabled = false }
                            }
                        }
                    } else {
                        Task { await NotificationScheduler.shared.cancelAll() }
                    }
                }
            )) {
                Label("Festival Reminders", systemImage: "bell")
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Get a morning reminder on festival and vrat days.")
        }
    }

    private var janmaSection: some View {
        Section {
            Picker("Janma Nakshatra", selection: Binding(
                get: { prefs.janmaNakshatra },
                set: { prefs.janmaNakshatra = $0 }
            )) {
                Text("Not set").tag(-1)
                ForEach(Array(PanchangNames.nakshatra.enumerated()), id: \.offset) { i, name in
                    Text(name).tag(i)
                }
            }
            Picker("Janma Rashi", selection: Binding(
                get: { prefs.janmaRashi },
                set: { prefs.janmaRashi = $0 }
            )) {
                Text("Not set").tag(-1)
                ForEach(Array(PanchangNames.rashi.enumerated()), id: \.offset) { i, name in
                    Text(name).tag(i)
                }
            }
        } header: {
            Text("Birth Details")
        } footer: {
            Text("Set your janma nakshatra and rashi to see Tara Bala and Chandra Bala in the Muhurta tab. A primary Kundli profile fills these automatically.")
        }
    }

    private var kundliSection: some View {
        Section {
            Picker("Kundli Style", selection: Binding(
                get: { prefs.kundliStyle },
                set: { prefs.kundliStyle = $0 }
            )) {
                Text("North Indian").tag("north")
                Text("South Indian").tag("south")
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Kundli Chart Style")
        } footer: {
            Text("North Indian uses a fixed-house diamond; South Indian uses a fixed-sign grid.")
        }
    }

    private var scriptSection: some View {
        Section {
            Picker("Script", selection: Binding(
                get: { prefs.scriptMode },
                set: { prefs.scriptMode = $0 }
            )) {
                Text("Transliteration (IAST)").tag("transliteration")
                Text("Devanagari").tag("devanagari")
                Text("English").tag("english")
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Script")
        } footer: {
            Text("How Sanskrit terms are displayed throughout the app.")
        }
    }
}
