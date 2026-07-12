import SwiftUI
import SwiftData
import UIKit
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

    private var locationName: String {
        savedLocations.first(where: { $0.isActive })?.name ?? "San Jose"
    }

    private var config: CalendarConfig {
        prefsQuery.first?.calendarPreset == "north_indian" ? .northIndian : .gujaratiWestern
    }

    private var scriptMode: String { prefsQuery.first?.scriptMode ?? "transliteration" }
    private var region: String? { prefsQuery.first?.contentRegion }

    var body: some View {
        NavigationStack {
            Group {
                switch vm.state {
                case .idle:
                    Color.clear.onAppear { vm.load(location: activeLocation, config: config, region: region, includeUpcoming: true) }
                case .loading:
                    ProgressView("Computing panchang…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .loaded(let day, let festivals):
                    let resolved = ContentResolver().resolve(for: day, region: region)
                    TodayHomeView(day: day, festivals: festivals,
                                  resolvedContent: resolved, upcoming: vm.upcoming,
                                  scriptMode: scriptMode, locationName: locationName)
                        .refreshable { vm.refresh(location: activeLocation, config: config, region: region, includeUpcoming: true) }
                case .failed(let msg):
                    ContentUnavailableView("Unable to compute",
                                          systemImage: "exclamationmark.triangle",
                                          description: Text(msg))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: savedLocations.first(where: { $0.isActive })?.name) { _, _ in
                vm.load(location: activeLocation, config: config, region: region, includeUpcoming: true)
            }
            .onChange(of: prefsQuery.first?.calendarPreset) { _, _ in
                vm.load(location: activeLocation, config: config, region: region, includeUpcoming: true)
            }
            .onChange(of: prefsQuery.first?.contentRegion) { _, _ in
                vm.load(location: activeLocation, config: config, region: region, includeUpcoming: true)
            }
        }
    }
}

// MARK: - Editorial home screen

/// The "meaning of today" home screen: moon arc, dual dates, one hero statement,
/// and what's coming up. The full data tables live behind the "Full panchang" link
/// (and in the Calendar tab via `PanchangDayView`).
struct TodayHomeView: View {
    let day: PanchangDay
    var festivals: [FestivalOccurrence] = []
    var resolvedContent: [ResolvedContent] = []
    var upcoming: [UpcomingObservance] = []
    var scriptMode: String = "transliteration"
    var locationName: String = "San Jose"

    private var renderer: ScriptRenderer { ScriptRenderer(mode: scriptMode) }

    /// Highest-priority content matched today, if any — drives the hero and the mood.
    private var heroContent: ResolvedContent? { resolvedContent.first }

    private var mood: DayMood {
        guard let entry = heroContent?.entry else { return .ordinary }
        if entry.festivalType == "festival" && entry.tier == 1 { return .festival }
        if entry.id.contains("ekadashi") { return .ekadashi }
        return .ordinary
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerLine
                MoonArcView(phase: moonPhase, accent: mood.accent)
                    .frame(height: 92)
                    .padding(.top, 18)
                    .accessibilityHidden(true)
                Text(moonCaption)
                    .font(.system(size: 12.5))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.inkFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 26)
                dateDuality
                hero
                if let content = heroContent {
                    NavigationLink(destination: FestivalDetailView(content: content)) {
                        HStack(spacing: 8) {
                            Text(deeperLabel(for: content))
                                .font(.system(size: 15, design: .serif))
                                .italic()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(mood.accent)
                    }
                    .padding(.vertical, 10)
                    .padding(.bottom, 10)
                }
                alsoToday
                if day.sunNeverRises || day.sunNeverSets { polarNote }
                Divider().overlay(Palette.hairline).padding(.bottom, 18)
                comingUp
                fullPanchangLink
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .background(mood.background.ignoresSafeArea())
    }

    // MARK: Sections

    private var headerLine: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(locationName) · today")
                .font(.system(size: 14))
                .foregroundStyle(Palette.inkMuted)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 12))
                Text("\(formatTime12(day.timings.sunrise)) · \(formatTime12(day.timings.sunset))")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(mood.accent)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sunrise \(formatTime12(day.timings.sunrise)), sunset \(formatTime12(day.timings.sunset))")
        }
    }

    private var dateDuality: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(formattedCivilDate)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Palette.inkStrong)
            (Text("\(displayedMasaName) · \(renderer.paksha(day.tithi.paksha)) Paksha · ")
                .foregroundStyle(Palette.inkMuted)
             + Text(renderer.tithiName(index: day.tithi.index))
                .foregroundStyle(mood.accent))
                .font(.system(size: 15))
        }
        .padding(.bottom, 18)
        .accessibilityElement(children: .combine)
    }

    private var hero: some View {
        let (meaning, sub) = heroText
        return VStack(alignment: .leading, spacing: 16) {
            Text(meaning)
                .font(.system(size: mood == .festival ? 33 : 28, design: .serif))
                .foregroundStyle(Palette.ink)
                .lineSpacing(4)
            if let sub {
                Text(sub)
                    .font(.system(size: 16.5))
                    .foregroundStyle(Palette.inkSecondary)
                    .lineSpacing(5)
            }
        }
        .padding(.bottom, 8)
    }

    /// Other observances matched today beyond the hero (e.g. an Ekadashi that falls
    /// inside Navratri) — quiet links so nothing authored gets buried.
    @ViewBuilder
    private var alsoToday: some View {
        let others = resolvedContent.dropFirst().filter { $0.entry.tier <= 2 }
        if !others.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(others) { content in
                    NavigationLink(destination: FestivalDetailView(content: content)) {
                        HStack(spacing: 6) {
                            Text("Also today: \(content.entry.name)")
                                .font(.system(size: 14, design: .serif))
                                .italic()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Palette.inkMuted)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    private var polarNote: some View {
        Text(day.sunNeverRises ? "The sun does not rise today at this location."
                               : "The sun does not set today at this location.")
            .font(.system(size: 13))
            .foregroundStyle(Palette.inkMuted)
            .padding(.bottom, 16)
    }

    private var comingUp: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Coming up")
                .font(.system(size: 12.5))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Palette.inkFaint)
                .padding(.bottom, 14)
            ForEach(Array(upcoming.enumerated()), id: \.element.id) { i, item in
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.system(size: 18, design: .serif))
                                .foregroundStyle(Palette.inkStrong)
                            if let tagline = item.tagline {
                                Text(tagline)
                                    .font(.system(size: 13.5))
                                    .foregroundStyle(Palette.inkFaint)
                            }
                        }
                        Spacer()
                        Text(item.daysAway == 1 ? "tomorrow" : "in \(item.daysAway) days")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(mood.accent)
                    }
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                    if i < upcoming.count - 1 {
                        Divider().overlay(Palette.hairline.opacity(0.6))
                    }
                }
            }
        }
    }

    private var fullPanchangLink: some View {
        NavigationLink {
            PanchangDayView(day: day, festivals: festivals,
                            scriptMode: scriptMode, resolvedContent: resolvedContent)
                .navigationTitle("Full panchang")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.visible, for: .navigationBar)
        } label: {
            HStack(spacing: 8) {
                Text("Full panchang")
                    .font(.system(size: 15, design: .serif))
                    .italic()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(Palette.inkMuted)
        }
        .padding(.top, 24)
    }

    // MARK: Derived values

    /// 0 = new moon, 0.5 = full, 1 = new again — the marker's position along the arc.
    private var moonPhase: Double {
        (Double(day.tithi.index) + 0.5) / 30.0
    }

    private var moonCaption: String {
        switch day.tithi.index {
        case 14: return "Full moon"
        case 29: return "New moon"
        default: return day.tithi.paksha == .shukla ? "Waxing moon" : "Waning moon"
        }
    }

    /// Splits authored morning text into a serif headline and a quieter subline.
    /// Very short opening sentences ("Ekadashi.") pull the next one into the headline.
    private var heroText: (String, String?) {
        if let content = heroContent {
            return splitHero(content.voice.morning.text)
        }
        if day.tithi.paksha == .shukla {
            return ("The moon is waxing toward full — a building, beginning kind of day.",
                    "Good energy for starting things, less for finishing them.")
        }
        return ("The moon is waning toward new — a clearing, finishing kind of day.",
                "Good energy for completing things, and for letting go.")
    }

    private func splitHero(_ text: String) -> (String, String?) {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { s, _, _, _ in
            if let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                sentences.append(s)
            }
        }
        guard sentences.count > 1 else { return (text, nil) }
        var headCount = 1
        if sentences[0].count < 30, sentences.count > 2 { headCount = 2 }
        let head = sentences[..<headCount].joined(separator: " ")
        let rest = sentences[headCount...].joined(separator: " ")
        return (head, rest.isEmpty ? nil : rest)
    }

    private func deeperLabel(for content: ResolvedContent) -> String {
        "\(content.entry.name) — the story underneath"
    }

    private var displayedMasaName: String {
        let idx = day.masa.amantaIndex
        // Purnimanta shifts Krishna-paksha labels by one month
        if day.config.monthEnd == .purnimanta, day.tithi.paksha == .krishna {
            return renderer.masaName(amantaIndex: (idx + 1) % 12)
        }
        return renderer.masaName(amantaIndex: idx)
    }

    private var formattedCivilDate: String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = day.location.timeZone
        let date = cal.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        formatter.timeZone = day.location.timeZone
        return formatter.string(from: date)
    }

    private func formatTime12(_ jd: Double?) -> String {
        guard let jd else { return "–" }
        let c = JulianDate.components(julianDay: jd, timeZone: day.location.timeZone)
        var h = (c.hour ?? 0) % 12
        if h == 0 { h = 12 }
        return String(format: "%d:%02d", h, c.minute ?? 0)
    }
}

// MARK: - Day mood (accent + background per day-state)

private enum DayMood {
    case ordinary, ekadashi, festival

    var accent: Color {
        switch self {
        case .ordinary: return Color(light: 0xB5552D, dark: 0xD4764E) // terracotta
        case .ekadashi: return Color(light: 0x3E6B57, dark: 0x6FA089) // quiet green
        case .festival: return Color(light: 0xC8841A, dark: 0xE0A23F) // lamp gold
        }
    }

    var background: Color {
        switch self {
        case .ordinary: return Color(light: 0xFFFFFF, dark: 0x161412)
        case .ekadashi: return Color(light: 0xFBFCFB, dark: 0x141614)
        case .festival: return Color(light: 0xFFFBF2, dark: 0x1A1610)
        }
    }
}

/// Warm-neutral text palette from the mockup, with dark-mode counterparts.
private enum Palette {
    static let ink = Color(light: 0x1A1712, dark: 0xF2EEE6)
    static let inkStrong = Color(light: 0x34302A, dark: 0xE5E0D6)
    static let inkSecondary = Color(light: 0x6B6557, dark: 0xB3AC9D)
    static let inkMuted = Color(light: 0x8A8578, dark: 0x99927F)
    static let inkFaint = Color(light: 0xA39E90, dark: 0x847E6E)
    static let hairline = Color(light: 0xE7E2D8, dark: 0x33302A)
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

// MARK: - Moon arc

/// The signature graphic: a thin semicircular arc for the lunar month, ticks at the
/// quarter points, and a glowing marker at today's phase (0 = new … 0.5 = full … 1 = new).
private struct MoonArcView: View {
    let phase: Double
    let accent: Color

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 100, size.height / 60)
            let ox = (size.width - 100 * scale) / 2
            func pt(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: ox + x * scale, y: y * scale)
            }
            let cx = 50.0, cy = 50.0, r = 38.0

            var arc = Path()
            arc.addArc(center: pt(cx, cy), radius: r * scale,
                       startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            context.stroke(arc, with: .color(Palette.hairline), lineWidth: 1.2 * scale)

            for t in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let a = Double.pi * (1 - t)
                var tick = Path()
                tick.move(to: pt(cx - (r - 3) * cos(a), cy - (r - 3) * sin(a)))
                tick.addLine(to: pt(cx - (r + 3) * cos(a), cy - (r + 3) * sin(a)))
                context.stroke(tick, with: .color(Palette.hairline), lineWidth: 1 * scale)
            }

            let a = Double.pi * (1 - min(max(phase, 0), 1))
            let marker = pt(cx - r * cos(a), cy - r * sin(a))
            let glow = Path(ellipseIn: CGRect(x: marker.x - 9 * scale, y: marker.y - 9 * scale,
                                              width: 18 * scale, height: 18 * scale))
            context.fill(glow, with: .color(accent.opacity(0.14)))
            let dot = Path(ellipseIn: CGRect(x: marker.x - 4.5 * scale, y: marker.y - 4.5 * scale,
                                             width: 9 * scale, height: 9 * scale))
            context.fill(dot, with: .color(accent))
        }
    }
}

// MARK: - Main content

struct PanchangDayView: View {
    let day: PanchangDay
    var festivals: [FestivalOccurrence] = []
    var scriptMode: String = "transliteration"
    var resolvedContent: [ResolvedContent] = []

    private var renderer: ScriptRenderer { ScriptRenderer(mode: scriptMode) }

    var body: some View {
        List {
            dateHeaderSection
            if day.sunNeverRises || day.sunNeverSets { polarWarningSection }
            if !festivalsWithContent.isEmpty { festivalsSection }
            sunMoonSection
            fiveLimbsSection
            monthYearSection
            muhurtaSection
        }
        .listStyle(.insetGrouped)
    }

    private var festivalsWithContent: [(FestivalOccurrence, ResolvedContent)] {
        festivals.compactMap { f in
            guard let content = resolvedContent.first(where: {
                $0.entry.id == f.id ||
                f.id.hasPrefix($0.entry.id + "_") ||
                f.id.hasSuffix("_" + $0.entry.id)
            }) else { return nil }
            return (f, content)
        }
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
            ForEach(festivalsWithContent, id: \.0.id) { f, content in
                NavigationLink(destination: FestivalDetailView(content: content)) {
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
