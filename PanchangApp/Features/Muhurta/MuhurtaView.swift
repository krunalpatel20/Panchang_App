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
            .background(Palette.paper.ignoresSafeArea())
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

    /// The moment "now," in the same Julian-day (UT) space as segment/window bounds,
    /// so the current choghadiya/hora row can be highlighted.
    private var nowJD: Double { JulianDate.julianDay(from: Date()) }

    private func isCurrent(_ start: Double, _ end: Double) -> Bool {
        nowJD >= start && nowJD < end
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                choghadiyaSection("Choghadiya — Day", day.choghadiya.day)
                choghadiyaSection("Choghadiya — Night", day.choghadiya.night)
                windowsSection("Dur Muhurtam", day.durMuhurtam, inauspicious: true)
                windowsSection("Varjyam", day.varjyam, inauspicious: true)
                windowsSection("Amrit Kalam", day.amritKalam, inauspicious: false)
                horaSection
                if janmaNakshatra >= 0 || janmaRashi >= 0 { balaSection }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .background(Palette.paper.ignoresSafeArea())
    }

    // MARK: Choghadiya

    private func choghadiyaSection(_ title: String, _ segments: [Choghadiya.Segment]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader(title)
                .padding(.bottom, 14)
            ForEach(Array(segments.enumerated()), id: \.element.id) { i, seg in
                let current = isCurrent(seg.start, seg.end)
                HStack(spacing: 12) {
                    AccentDot(color: dotColor(seg.quality))
                    Text(seg.name)
                        .font(.bodySans())
                        .foregroundStyle(Palette.inkStrong)
                    Spacer()
                    Text("\(time(seg.start)) – \(time(seg.end))")
                        .font(.dataSans)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .padding(.vertical, 11)
                .background(current ? Palette.accent.opacity(0.04) : Color.clear)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(seg.name), \(qualityLabel(seg.quality)), \(time(seg.start)) to \(time(seg.end))")
                if i < segments.count - 1 {
                    HairlineDivider(opacity: 0.6)
                }
            }
        }
        .padding(.bottom, 28)
    }

    private func dotColor(_ q: Choghadiya.Quality) -> Color {
        switch q { case .good: return Palette.auspicious; case .bad: return Palette.inauspicious; case .neutral: return Palette.inkFaint }
    }
    private func qualityLabel(_ q: Choghadiya.Quality) -> String {
        switch q { case .good: return "auspicious"; case .bad: return "inauspicious"; case .neutral: return "neutral" }
    }

    // MARK: Windows

    private func windowsSection(_ title: String, _ windows: [MuhurtaWindow], inauspicious: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader(title)
                .padding(.bottom, 14)
            if windows.isEmpty {
                Text("None today")
                    .font(.bodySans())
                    .foregroundStyle(Palette.inkMuted)
                    .padding(.vertical, 11)
            } else {
                ForEach(Array(windows.enumerated()), id: \.offset) { i, w in
                    HStack {
                        AccentDot(color: inauspicious ? Palette.inauspicious : Palette.auspicious)
                        Spacer()
                        if let s = w.start, let e = w.end {
                            Text("\(time(s)) – \(time(e))")
                                .font(.dataSans)
                                .foregroundStyle(Palette.inkSecondary)
                        } else {
                            Text("–")
                                .font(.dataSans)
                                .foregroundStyle(Palette.inkSecondary)
                        }
                    }
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel({
                        if let s = w.start, let e = w.end { return "\(title): \(time(s)) to \(time(e))" }
                        return "\(title): not available"
                    }())
                    if i < windows.count - 1 {
                        HairlineDivider(opacity: 0.6)
                    }
                }
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: Hora

    private var horaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader("Hora")
                .padding(.bottom, 14)
            ForEach(Array(day.horas.enumerated()), id: \.element.id) { i, h in
                let current = isCurrent(h.start, h.end)
                HStack {
                    Text(h.planet)
                        .font(.bodySans())
                        .foregroundStyle(Palette.inkStrong)
                    Spacer()
                    Text("\(time(h.start)) – \(time(h.end))")
                        .font(.dataSans)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .padding(.vertical, 11)
                .background(current ? Palette.accent.opacity(0.04) : Color.clear)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(h.planet) hora, \(time(h.start)) to \(time(h.end))")
                if i < day.horas.count - 1 {
                    HairlineDivider(opacity: 0.6)
                }
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: Bala

    @ViewBuilder
    private var balaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader("Bala")
                .padding(.bottom, 14)
            if janmaNakshatra >= 0 {
                let t = TaraBala.compute(janmaNakshatra: janmaNakshatra, dayNakshatra: day.nakshatra.index)
                AlmanacRow(label: "Tara Bala", value: t.name,
                           dotColor: t.isAuspicious ? Palette.auspicious : Palette.inauspicious)
                    .padding(.vertical, 11)
                if janmaRashi >= 0 { HairlineDivider(opacity: 0.6) }
            }
            if janmaRashi >= 0 {
                let c = ChandraBala.compute(janmaRashi: janmaRashi, moonRashi: day.moonRashiIndex)
                AlmanacRow(label: "Chandra Bala",
                           value: c.isAuspicious ? "Favourable (house \(c.house))" : "Weak (house \(c.house))",
                           dotColor: c.isAuspicious ? Palette.auspicious : Palette.inauspicious)
                    .padding(.vertical, 11)
            }
        }
        .padding(.bottom, 8)
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
