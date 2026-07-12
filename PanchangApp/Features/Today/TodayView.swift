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
                    .font(.trackedCaption)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.inkFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 26)
                dateDuality
                hero
                if let content = heroContent {
                    NavigationLink(destination: FestivalDetailView(content: content, mood: mood)) {
                        QuietLink(label: deeperLabel(for: content), color: mood.accent)
                    }
                    .padding(.vertical, 10)
                    .padding(.bottom, 10)
                }
                alsoToday
                if day.sunNeverRises || day.sunNeverSets { polarNote }
                HairlineDivider().padding(.bottom, 18)
                comingUp
                fullPanchangLink
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .background(mood.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.6), value: mood)
    }

    // MARK: Sections

    private var headerLine: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(locationName) · today")
                .font(.bodySans(14))
                .foregroundStyle(Palette.inkMuted)
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 12))
                Text("\(formatTime12(day.timings.sunrise)) · \(formatTime12(day.timings.sunset))")
                    .font(.bodySans(14).weight(.semibold))
            }
            .foregroundStyle(mood.accent)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Sunrise \(formatTime12(day.timings.sunrise)), sunset \(formatTime12(day.timings.sunset))")
        }
    }

    private var dateDuality: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(formattedCivilDate)
                .font(.bodySans(15).weight(.medium))
                .foregroundStyle(Palette.inkStrong)
            (Text("\(displayedMasaName) · \(renderer.paksha(day.tithi.paksha)) Paksha · ")
                .foregroundStyle(Palette.inkMuted)
             + Text(renderer.tithiName(index: day.tithi.index))
                .foregroundStyle(mood.accent))
                .font(.bodySans(15))
        }
        .padding(.bottom, 18)
        .accessibilityElement(children: .combine)
    }

    private var hero: some View {
        let (meaning, sub) = heroText
        return VStack(alignment: .leading, spacing: 16) {
            Text(meaning)
                .font(.heroSerif(festival: mood == .festival))
                .foregroundStyle(Palette.ink)
                .lineSpacing(4)
            if let sub {
                Text(sub)
                    .font(.bodySans(16.5))
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
                    NavigationLink(destination: FestivalDetailView(content: content, mood: mood)) {
                        QuietLink(label: "Also today: \(content.entry.name)", color: Palette.inkMuted)
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    private var polarNote: some View {
        Text(day.sunNeverRises ? "The sun does not rise today at this location."
                               : "The sun does not set today at this location.")
            .font(.bodySans(13))
            .foregroundStyle(Palette.inkMuted)
            .padding(.bottom, 16)
    }

    private var comingUp: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader("Coming up")
                .padding(.bottom, 14)
            ForEach(Array(upcoming.enumerated()), id: \.element.id) { i, item in
                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.rowSerif)
                                .foregroundStyle(Palette.inkStrong)
                            if let tagline = item.tagline {
                                Text(tagline)
                                    .font(.tagSans)
                                    .foregroundStyle(Palette.inkFaint)
                            }
                        }
                        Spacer()
                        Text(item.daysAway == 1 ? "tomorrow" : "in \(item.daysAway) days")
                            .font(.tagSans.weight(.semibold))
                            .foregroundStyle(mood.accent)
                    }
                    .padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                    if i < upcoming.count - 1 {
                        HairlineDivider(opacity: 0.6)
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
            QuietLink(label: "Full panchang", color: Palette.inkMuted)
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
    ///
    /// Ordinary-day copy now lives in content.json (tier-6 `waxing_days`/`waning_days`,
    /// which match every day via the `.paksha` anchor), not as hardcoded strings here —
    /// `resolvedContent` should never be empty in practice, but a genuinely-empty case
    /// (e.g. a preview/test context with no content loaded) falls back to an empty hero
    /// rather than force-unwrapping.
    private var heroText: (String, String?) {
        splitHero(heroContent?.voice.morning.text ?? "")
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
