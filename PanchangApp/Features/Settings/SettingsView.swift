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

    var body: some View {
        NavigationStack {
            Form {
                locationSection
                calendarSection
                scriptSection
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
