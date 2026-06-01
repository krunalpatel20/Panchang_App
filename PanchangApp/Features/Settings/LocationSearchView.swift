import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct LocationSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var savedLocations: [SavedLocation]

    @State private var searchText = ""
    @State private var results: [MKLocalSearchCompletion] = []
    @StateObject private var completer = SearchCompleter()
    @State private var locationManager = LocationManager()
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Current Location") {
                    Button {
                        locationManager.requestLocation()
                    } label: {
                        Label {
                            switch locationManager.status {
                            case .locating:
                                Text("Detecting…")
                            case .denied:
                                Text("Location access denied — enable in Settings")
                            default:
                                Text("Use My Current Location")
                            }
                        } icon: {
                            if case .locating = locationManager.status {
                                ProgressView()
                            } else {
                                Image(systemName: "location.fill")
                            }
                        }
                    }
                    .disabled({ if case .locating = locationManager.status { return true }; return false }())
                }

                if !savedLocations.isEmpty {
                    Section("Saved") {
                        ForEach(savedLocations) { loc in
                            SavedLocationRow(loc: loc, onSelect: {
                                setActive(loc)
                                dismiss()
                            })
                        }
                        .onDelete { indexSet in
                            for i in indexSet { modelContext.delete(savedLocations[i]) }
                        }
                    }
                }

                if !searchText.isEmpty {
                    Section("Results") {
                        if results.isEmpty {
                            Text("No results").foregroundStyle(.secondary)
                        }
                        ForEach(results, id: \.self) { completion in
                            Button {
                                geocode(completion)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(completion.title)
                                    if !completion.subtitle.isEmpty {
                                        Text(completion.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Search city or address")
            .onChange(of: searchText) { _, new in completer.query = new }
            .onReceive(completer.$results) { results = $0 }
            .alert("Error", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: { Text(errorMessage ?? "") })
            .onChange(of: locationManager.status) { _, status in
                handleLocationStatus(status)
            }
        }
    }

    private func geocode(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { [self] response, error in
            Task { @MainActor in
                guard let item = response?.mapItems.first, error == nil else {
                    self.errorMessage = error?.localizedDescription ?? "Could not find location"
                    return
                }
                let coord = item.placemark.coordinate
                let tz = item.timeZone ?? .current
                let name = [item.name, item.placemark.locality, item.placemark.administrativeArea]
                    .compactMap { $0 }.first ?? completion.title
                self.save(name: name, latitude: coord.latitude, longitude: coord.longitude,
                          timeZoneIdentifier: tz.identifier)
            }
        }
    }

    private func handleLocationStatus(_ status: LocationManager.Status) {
        guard case .located(let loc) = status else { return }
        CLGeocoder().reverseGeocodeLocation(loc) { [self] placemarks, _ in
            Task { @MainActor in
                let name: String
                if let pm = placemarks?.first {
                    name = [pm.locality, pm.administrativeArea, pm.country]
                        .compactMap { $0 }.joined(separator: ", ")
                } else {
                    name = String(format: "%.2f, %.2f", loc.coordinate.latitude, loc.coordinate.longitude)
                }
                let tz = placemarks?.first?.timeZone ?? .current
                self.save(name: name, latitude: loc.coordinate.latitude,
                          longitude: loc.coordinate.longitude, timeZoneIdentifier: tz.identifier)
            }
        }
    }

    private func save(name: String, latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        for loc in savedLocations { loc.isActive = false }
        let existing = savedLocations.first {
            abs($0.latitude - latitude) < 0.01 && abs($0.longitude - longitude) < 0.01
        }
        if let existing {
            existing.isActive = true
        } else {
            let new = SavedLocation(name: name, latitude: latitude, longitude: longitude,
                                    timeZoneIdentifier: timeZoneIdentifier, isActive: true)
            modelContext.insert(new)
        }
        dismiss()
    }

    private func setActive(_ location: SavedLocation) {
        for loc in savedLocations { loc.isActive = false }
        location.isActive = true
    }
}

private struct SavedLocationRow: View {
    let loc: SavedLocation
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(loc.name)
                Spacer()
                if loc.isActive {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
        }
        .foregroundStyle(.primary)
    }
}

// MKLocalSearchCompleter wrapper
final class SearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []

    var query: String = "" {
        didSet { completer.queryFragment = query }
    }

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        super.init()
        completer.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
