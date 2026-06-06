import SwiftUI
import SwiftData
import MapKit
import PanchangKit

/// Add or edit a birth profile: name, birth date+time, and birthplace (which fixes lat/lon and
/// the birth timezone). Saving a primary profile also derives the janma nakshatra/rashi used by
/// the Muhurta tab's Tara/Chandra Bala.
struct BirthProfileFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [BirthProfile]

    var editing: BirthProfile?

    @State private var name = ""
    @State private var birthDate = Date()
    @State private var placeName = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var timeZoneIdentifier = TimeZone.current.identifier
    @State private var makePrimary = false

    @State private var searchText = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @StateObject private var completer = SearchCompleter()

    private var canSave: Bool { !name.isEmpty && latitude != nil && longitude != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                Section("Birth Date & Time") {
                    DatePicker("Born", selection: $birthDate, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.timeZone, TimeZone(identifier: timeZoneIdentifier) ?? .current)
                }
                Section("Birthplace") {
                    if let lat = latitude, let lon = longitude {
                        HStack {
                            Text(placeName.isEmpty ? "Selected" : placeName)
                            Spacer()
                            Text(String(format: "%.2f, %.2f", lat, lon))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    TextField("Search city", text: $searchText)
                    ForEach(results, id: \.self) { c in
                        Button {
                            geocode(c)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(c.title)
                                if !c.subtitle.isEmpty {
                                    Text(c.subtitle).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
                Section {
                    Toggle("Primary profile", isOn: $makePrimary)
                } footer: {
                    Text("The primary profile sets your janma nakshatra and rashi for Tara/Chandra Bala.")
                }
            }
            .navigationTitle(editing == nil ? "New Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: searchText) { _, new in completer.query = new }
            .onReceive(completer.$results) { results = $0 }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!canSave) }
            }
            .onAppear(perform: prefill)
        }
    }

    private func prefill() {
        guard let p = editing else {
            makePrimary = profiles.isEmpty   // first profile defaults to primary
            return
        }
        name = p.name
        birthDate = p.birthInstant
        placeName = p.placeName
        latitude = p.latitude
        longitude = p.longitude
        timeZoneIdentifier = p.timeZoneIdentifier
        makePrimary = p.isPrimary
    }

    private func geocode(_ completion: MKLocalSearchCompletion) {
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
        search.start { response, _ in
            Task { @MainActor in
                guard let item = response?.mapItems.first else { return }
                let coord = item.placemark.coordinate
                latitude = coord.latitude
                longitude = coord.longitude
                timeZoneIdentifier = (item.timeZone ?? .current).identifier
                placeName = [item.name, item.placemark.locality, item.placemark.administrativeArea]
                    .compactMap { $0 }.first ?? completion.title
                searchText = ""
                results = []
            }
        }
    }

    private func save() {
        guard let lat = latitude, let lon = longitude else { return }
        if makePrimary { for p in profiles { p.isPrimary = false } }

        let profile: BirthProfile
        if let editing {
            editing.name = name; editing.birthInstant = birthDate
            editing.latitude = lat; editing.longitude = lon
            editing.timeZoneIdentifier = timeZoneIdentifier; editing.placeName = placeName
            editing.isPrimary = makePrimary
            profile = editing
        } else {
            profile = BirthProfile(name: name, birthInstant: birthDate, latitude: lat, longitude: lon,
                                   timeZoneIdentifier: timeZoneIdentifier, placeName: placeName,
                                   isPrimary: makePrimary)
            modelContext.insert(profile)
        }
        if makePrimary { deriveJanma(from: profile) }
        dismiss()
    }

    /// Derive janma nakshatra/rashi from the Moon's sidereal position at birth, feeding the
    /// Muhurta tab's Tara/Chandra Bala without a second manual entry.
    private func deriveJanma(from profile: BirthProfile) {
        let loc = GeoLocation(latitude: profile.latitude, longitude: profile.longitude,
                              timeZoneIdentifier: profile.timeZoneIdentifier)
        let jd = JulianDate.julianDay(from: profile.birthInstant)
        let positions = Astrology().positions(julianDay: jd, location: loc)
        let moon = positions.planets[1]   // index 1 = Moon
        let prefs = (try? modelContext.fetch(FetchDescriptor<Preferences>()))?.first
        prefs?.janmaNakshatra = moon.nakshatra
        prefs?.janmaRashi = moon.rashi
    }
}
