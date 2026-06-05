import SwiftUI
import SwiftData
import PanchangKit

/// The Muhurta tab: Choghadiya grid, planetary Hora, and the Dur Muhurtam / Varjyam /
/// Amrit Kalam windows, plus Tara/Chandra Bala when the user's janma details are set.
struct MuhurtaView: View {
    @State private var vm = TodayViewModel()
    @Query private var savedLocations: [SavedLocation]
    @Query private var prefsQuery: [Preferences]

    private var activeLocation: GeoLocation {
        if let loc = savedLocations.first(where: { $0.isActive }) {
            return GeoLocation(latitude: loc.latitude, longitude: loc.longitude,
                               timeZoneIdentifier: loc.timeZoneIdentifier)
        }
        return GeoLocation(latitude: 37.3382, longitude: -121.8863, timeZoneIdentifier: "America/Los_Angeles")
    }

    private var config: CalendarConfig {
        prefsQuery.first?.calendarPreset == "north_indian" ? .northIndian : .gujaratiWestern
    }

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .idle:
                    Color.clear.onAppear { vm.load(location: activeLocation, config: config) }
                case .loading:
                    ProgressView("Computing muhurtas…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let day, _):
                    MuhurtaGridView(day: day,
                                    janmaNakshatra: prefsQuery.first?.janmaNakshatra ?? -1,
                                    janmaRashi: prefsQuery.first?.janmaRashi ?? -1)
                case .failed(let msg):
                    ContentUnavailableView("Unable to compute", systemImage: "exclamationmark.triangle",
                                           description: Text(msg))
                }
            }
            .navigationTitle("Muhurta")
            .onChange(of: savedLocations.first(where: { $0.isActive })?.name) { _, _ in
                vm.load(location: activeLocation, config: config)
            }
            .onChange(of: prefsQuery.first?.calendarPreset) { _, _ in
                vm.load(location: activeLocation, config: config)
            }
        }
    }
}

private struct MuhurtaGridView: View {
    let day: PanchangDay
    let janmaNakshatra: Int
    let janmaRashi: Int

    var body: some View {
        List {
            choghadiyaSection("Choghadiya — Day", day.choghadiya.day)
            choghadiyaSection("Choghadiya — Night", day.choghadiya.night)
            windowsSection("Dur Muhurtam", day.durMuhurtam, inauspicious: true)
            windowsSection("Varjyam", day.varjyam, inauspicious: true)
            windowsSection("Amrit Kalam", day.amritKalam, inauspicious: false)
            horaSection
            if janmaNakshatra >= 0 || janmaRashi >= 0 { balaSection }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Choghadiya

    private func choghadiyaSection(_ title: String, _ segments: [Choghadiya.Segment]) -> some View {
        Section(title) {
            ForEach(segments) { seg in
                HStack(spacing: 12) {
                    Circle().fill(color(seg.quality)).frame(width: 10, height: 10)
                    Text(seg.name)
                    Spacer()
                    Text("\(time(seg.start)) – \(time(seg.end))")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(seg.name), \(qualityLabel(seg.quality)), \(time(seg.start)) to \(time(seg.end))")
            }
        }
    }

    private func color(_ q: Choghadiya.Quality) -> Color {
        switch q { case .good: return .green; case .bad: return .red; case .neutral: return .yellow }
    }
    private func qualityLabel(_ q: Choghadiya.Quality) -> String {
        switch q { case .good: return "auspicious"; case .bad: return "inauspicious"; case .neutral: return "neutral" }
    }

    // MARK: Windows

    private func windowsSection(_ title: String, _ windows: [MuhurtaWindow], inauspicious: Bool) -> some View {
        Section(title) {
            if windows.isEmpty {
                Text("None today").foregroundStyle(.secondary)
            } else {
                ForEach(Array(windows.enumerated()), id: \.offset) { _, w in
                    HStack {
                        Image(systemName: inauspicious ? "exclamationmark.triangle" : "drop.fill")
                            .foregroundStyle(inauspicious ? .red : .green)
                        Spacer()
                        if let s = w.start, let e = w.end {
                            Text("\(time(s)) – \(time(e))").foregroundStyle(.secondary).monospacedDigit()
                        } else {
                            Text("–").foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: Hora

    private var horaSection: some View {
        Section("Hora") {
            ForEach(day.horas) { h in
                HStack {
                    Text(h.planet)
                    Spacer()
                    Text("\(time(h.start)) – \(time(h.end))").foregroundStyle(.secondary).monospacedDigit()
                }
            }
        }
    }

    // MARK: Bala

    private var balaSection: some View {
        Section("Bala") {
            if janmaNakshatra >= 0 {
                let t = TaraBala.compute(janmaNakshatra: janmaNakshatra, dayNakshatra: day.nakshatra.index)
                HStack {
                    Label("Tara Bala", systemImage: "star")
                    Spacer()
                    Text(t.name).foregroundStyle(t.isAuspicious ? .green : .red)
                }
            }
            if janmaRashi >= 0 {
                let c = ChandraBala.compute(janmaRashi: janmaRashi, moonRashi: day.moonRashiIndex)
                HStack {
                    Label("Chandra Bala", systemImage: "moon")
                    Spacer()
                    Text(c.isAuspicious ? "Favourable (house \(c.house))" : "Weak (house \(c.house))")
                        .foregroundStyle(c.isAuspicious ? .green : .red)
                }
            }
        }
    }

    // MARK: Time formatting

    private func time(_ jd: Double) -> String {
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
    let day = Panchang().compute(year: 2024, month: 12, day: 21, location: loc, config: .gujaratiWestern)
    return MuhurtaGridView(day: day, janmaNakshatra: 14, janmaRashi: 6)
}
