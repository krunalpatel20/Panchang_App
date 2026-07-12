import SwiftUI
import SwiftData
import PanchangKit

/// The Kundli tab: pick a birth profile, see its chakra (North/South), planet table, and
/// Vimshottari dasha. Empty state prompts to add the first profile.
struct KundliView: View {
    @Query(sort: \BirthProfile.createdAt) private var profiles: [BirthProfile]
    @Query private var prefsQuery: [Preferences]

    @State private var vm = KundliViewModel()
    @State private var selectedID: PersistentIdentifier?
    @State private var showForm = false
    @State private var editingProfile: BirthProfile?

    private var kundliStyle: String { prefsQuery.first?.kundliStyle ?? "north" }

    private var selectedProfile: BirthProfile? {
        profiles.first { $0.persistentModelID == selectedID }
            ?? profiles.first { $0.isPrimary }
            ?? profiles.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if profiles.isEmpty {
                    ContentUnavailableView {
                        Label("No Birth Profiles", systemImage: "person.crop.circle.badge.plus")
                    } description: {
                        Text("Add a birth date, time, and place to see the kundli chart and Vimshottari dasha.")
                    } actions: {
                        Button("Add Profile") { editingProfile = nil; showForm = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    content
                }
            }
            .navigationTitle("Kundli")
            .background(Palette.paper)
            .toolbar {
                if !profiles.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { editingProfile = nil; showForm = true } label: { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(isPresented: $showForm) {
                BirthProfileFormView(editing: editingProfile)
            }
            .onChange(of: selectedProfile?.persistentModelID) { _, _ in loadSelected() }
            .onChange(of: kundliStyle) { _, _ in }   // chart re-renders from prefs automatically
            .onAppear { loadSelected() }
        }
    }

    private var content: some View {
        List {
            if profiles.count > 1 {
                Section {
                    Picker("Profile", selection: Binding(
                        get: { selectedProfile?.persistentModelID },
                        set: { selectedID = $0 }
                    )) {
                        ForEach(profiles) { p in
                            Text(p.name).tag(Optional(p.persistentModelID))
                        }
                    }
                }
            }

            switch vm.state {
            case .empty, .loading:
                Section { ProgressView().tint(Palette.accent).frame(maxWidth: .infinity) }
            case .loaded(let positions, let dasha):
                Section { ChartView(positions: positions, style: kundliStyle).padding(.vertical, 8) }
                Section { PlanetTableView(positions: positions) } header: { EditorialSectionHeader("Planets") }
                Section { DashaTimelineView(dasha: dasha) } header: { EditorialSectionHeader("Vimshottari Dasha") }
            }

            if let p = selectedProfile {
                Section {
                    Button("Edit \(p.name)") { editingProfile = p; showForm = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.paper)
    }

    private func loadSelected() {
        guard let p = selectedProfile else { return }
        let loc = GeoLocation(latitude: p.latitude, longitude: p.longitude,
                              timeZoneIdentifier: p.timeZoneIdentifier)
        vm.load(birthInstant: p.birthInstant, location: loc)
    }
}
