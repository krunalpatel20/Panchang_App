import SwiftUI
import SwiftData
import PanchangKit

struct TodayView: View {
    @State private var vm = TodayViewModel()
    @Query private var savedLocations: [SavedLocation]
    @Query private var prefsQuery: [Preferences]

    private var activeLocation: GeoLocation {
        if let loc = savedLocations.first(where: { $0.isActive }) {
            return GeoLocation(latitude: loc.latitude, longitude: loc.longitude,
                               timeZoneIdentifier: loc.timeZoneIdentifier)
        }
        return GeoLocation(latitude: 37.3382, longitude: -121.8863,
                           timeZoneIdentifier: "America/Los_Angeles")
    }

    private var config: CalendarConfig {
        prefsQuery.first?.calendarPreset == "north_indian" ? .northIndian : .gujaratiWestern
    }

    private var scriptMode: String { prefsQuery.first?.scriptMode ?? "transliteration" }

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .idle:
                    Color.clear.onAppear { vm.load(location: activeLocation, config: config) }
                case .loading:
                    ProgressView("Computing panchang…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let day, let festivals):
                    PanchangDayView(day: day, festivals: festivals, scriptMode: scriptMode)
                case .failed(let msg):
                    ContentUnavailableView("Unable to compute",
                                          systemImage: "exclamationmark.triangle",
                                          description: Text(msg))
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { vm.refresh(location: activeLocation, config: config) } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh panchang")
                }
            }
            .onChange(of: savedLocations.first(where: { $0.isActive })?.name) { _, _ in
                vm.load(location: activeLocation, config: config)
            }
            .onChange(of: prefsQuery.first?.calendarPreset) { _, _ in
                vm.load(location: activeLocation, config: config)
            }
        }
    }
}

// MARK: - Main content

struct PanchangDayView: View {
    let day: PanchangDay
    var festivals: [FestivalOccurrence] = []
    var scriptMode: String = "transliteration"

    private var renderer: ScriptRenderer { ScriptRenderer(mode: scriptMode) }

    var body: some View {
        List {
            dateHeaderSection
            if day.sunNeverRises || day.sunNeverSets { polarWarningSection }
            if !festivals.isEmpty { festivalsSection }
            sunMoonSection
            fiveLimbsSection
            monthYearSection
            muhurtaSection
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Sections

    private var dateHeaderSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedCivilDate)
                        .font(.title2).bold()
                    Text("\(renderer.rituName(index: day.yearInfo.rituIndex)) · \(day.yearInfo.ayana)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("VS \(day.displayedVikramSamvat)")
                        .font(.headline)
                    masaBadge
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    private var masaBadge: some View {
        HStack(spacing: 4) {
            Text(displayedMasaName)
            if day.masa.isAdhika {
                Text("Adhika")
                    .font(.caption2).bold()
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
            }
            if day.masa.isKshaya {
                Text("Kshaya")
                    .font(.caption2).bold()
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.red.opacity(0.15), in: Capsule())
                    .foregroundStyle(.red)
            }
        }
        .font(.subheadline).foregroundStyle(.secondary)
    }

    private var displayedMasaName: String {
        let idx = day.masa.amantaIndex
        let base = renderer.masaName(amantaIndex: idx)
        switch day.config.monthEnd {
        case .purnimanta:
            // Purnimanta shifts Krishna-paksha label by one month
            if day.tithi.paksha == .krishna {
                let shifted = (idx + 1) % 12
                return renderer.masaName(amantaIndex: shifted)
            }
            return base
        case .amanta:
            return base
        }
    }

    private var polarWarningSection: some View {
        Section {
            if day.sunNeverRises {
                Label("Sun does not rise today at this location.", systemImage: "sun.haze")
                    .foregroundStyle(.secondary).font(.subheadline)
            }
            if day.sunNeverSets {
                Label("Sun does not set today at this location.", systemImage: "sun.max")
                    .foregroundStyle(.secondary).font(.subheadline)
            }
        }
    }

    private var festivalsSection: some View {
        Section("Festivals & Vrats") {
            ForEach(festivals) { f in
                HStack {
                    Image(systemName: f.type == .vrat ? "moon.stars" : "star.fill")
                        .foregroundStyle(f.type == .vrat ? .indigo : .orange)
                    Text(f.name)
                    Spacer()
                    Text(f.type.rawValue.capitalized)
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(f.name), \(f.type.rawValue)")
            }
        }
    }

    private var sunMoonSection: some View {
        Section("Sun & Moon") {
            timingRow(label: "Sunrise", value: day.timings.sunrise,
                      systemImage: "sunrise.fill", color: .orange)
            timingRow(label: "Sunset", value: day.timings.sunset,
                      systemImage: "sunset.fill", color: .red)
            timingRow(label: "Moonrise", value: day.timings.moonrise,
                      systemImage: "moonrise.fill", color: .indigo)
            timingRow(label: "Moonset", value: day.timings.moonset,
                      systemImage: "moonset.fill", color: .purple)
        }
    }

    private var fiveLimbsSection: some View {
        Section("Panchang") {
            limbRow(label: "Tithi",
                    value: "\(renderer.paksha(day.tithi.paksha)) \(renderer.tithiName(index: day.tithi.index))",
                    ends: day.tithi.endJulianDay,
                    systemImage: "moon.circle")
            limbRow(label: "Vara",
                    value: renderer.varaName(index: day.vara.index),
                    ends: nil,
                    systemImage: "calendar")
            limbRow(label: "Nakshatra",
                    value: renderer.nakshatraName(index: day.nakshatra.index),
                    ends: day.nakshatra.endJulianDay,
                    systemImage: "sparkles")
            limbRow(label: "Yoga",
                    value: renderer.yogaName(index: day.yoga.index),
                    ends: day.yoga.endJulianDay,
                    systemImage: "circle.hexagongrid")
            limbRow(label: "Karana",
                    value: renderer.karanaName(halfTithiIndex: day.karana.index),
                    ends: day.karana.endJulianDay,
                    systemImage: "circle.hexagon")
        }
    }

    private var monthYearSection: some View {
        Section("Calendar") {
            LabeledContent("Masa (Amanta)",
                           value: renderer.masaName(amantaIndex: day.masa.amantaIndex)
                               + (day.masa.isAdhika ? " (Adhika)" : ""))
            LabeledContent("Masa (Purnimanta)",
                           value: renderer.masaName(amantaIndex: day.masa.purnimantaIndex)
                               + (day.masa.isAdhika ? " (Adhika)" : ""))
            LabeledContent("Vikram Samvat (North Indian)", value: "\(day.yearInfo.vikramSamvatChaitradi)")
            LabeledContent("Vikram Samvat (Gujarati)", value: "\(day.yearInfo.vikramSamvatKartikadi)")
            LabeledContent("Season (Ritu)", value: renderer.rituName(index: day.yearInfo.rituIndex))
            LabeledContent("Ayana", value: day.yearInfo.ayana)
        }
    }

    private var muhurtaSection: some View {
        Section("Muhurtas") {
            muhurtaRow(label: "Brahma Muhurta", window: day.muhurtas.brahmaMuhurta, systemImage: "moon.stars")
            muhurtaRow(label: "Abhijit", window: day.muhurtas.abhijit, systemImage: "sun.max")
            muhurtaRow(label: "Rahu Kalam", window: day.muhurtas.rahuKalam,
                       systemImage: "exclamationmark.triangle", inauspicious: true)
            muhurtaRow(label: "Yamaganda", window: day.muhurtas.yamaganda,
                       systemImage: "exclamationmark.triangle", inauspicious: true)
            muhurtaRow(label: "Gulika Kalam", window: day.muhurtas.gulika,
                       systemImage: "exclamationmark.triangle", inauspicious: true)
        }
    }

    // MARK: - Row helpers

    private func timingRow(label: String, value: Double?, systemImage: String, color: Color) -> some View {
        HStack {
            Label(label, systemImage: systemImage).foregroundStyle(color)
            Spacer()
            Text(value.map { formatTime($0) } ?? "–")
                .foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value.map { formatTime($0) } ?? "not available")")
    }

    private func limbRow(label: String, value: String, ends: Double?, systemImage: String) -> some View {
        HStack(alignment: .top) {
            Label(label, systemImage: systemImage)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(value).foregroundStyle(.primary)
                if let ends {
                    Text("ends \(formatTime(ends))")
                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)\(ends.map { ", ends \(formatTime($0))" } ?? "")")
    }

    private func muhurtaRow(label: String, window: MuhurtaWindow, systemImage: String,
                            inauspicious: Bool = false) -> some View {
        HStack {
            Label(label, systemImage: systemImage).foregroundStyle(inauspicious ? .red : .green)
            Spacer()
            if let s = window.start, let e = window.end {
                Text("\(formatTime(s)) – \(formatTime(e))")
                    .foregroundStyle(.secondary).monospacedDigit()
            } else {
                Text("–").foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel({
            if let s = window.start, let e = window.end {
                return "\(label): \(formatTime(s)) to \(formatTime(e))"
            }
            return "\(label): not available"
        }())
    }

    // MARK: - Formatting

    private var formattedCivilDate: String {
        let date = JulianDate.date(from: day.timings.sunrise ?? JulianDate.julianDay(from: Date()))
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.timeZone = day.location.timeZone
        return formatter.string(from: date)
    }

    private func formatTime(_ jd: Double) -> String {
        let tz = day.location.timeZone
        let c = JulianDate.components(julianDay: jd, timeZone: tz)
        let h = c.hour ?? 0, m = c.minute ?? 0
        if let sunrise = day.timings.sunrise {
            let sd = JulianDate.components(julianDay: sunrise, timeZone: tz).day ?? 0
            if (c.day ?? 0) != sd { return String(format: "%02d:%02d +1", h, m) }
        }
        return String(format: "%02d:%02d", h, m)
    }
}

#Preview {
    let loc = GeoLocation(latitude: 37.3382, longitude: -121.8863, timeZoneIdentifier: "America/Los_Angeles")
    let day = Panchang().compute(year: 2026, month: 5, day: 28, location: loc, config: .gujaratiWestern)
    return PanchangDayView(day: day)
}
