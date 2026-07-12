import SwiftUI
import PanchangKit

// MARK: - Main content

/// The full almanac register: every panchang limb, muhurta, and matched
/// festival for the day — a well-set reference page, not a settings screen.
struct PanchangDayView: View {
    let day: PanchangDay
    var festivals: [FestivalOccurrence] = []
    var scriptMode: String = "transliteration"
    var resolvedContent: [ResolvedContent] = []

    private var renderer: ScriptRenderer { ScriptRenderer(mode: scriptMode) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                dateHeaderSection
                if day.sunNeverRises || day.sunNeverSets { polarWarningSection }
                if !festivalsWithContent.isEmpty { festivalsSection }
                sunMoonSection
                fiveLimbsSection
                monthYearSection
                muhurtaSection
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
        .background(Palette.paper.ignoresSafeArea())
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedCivilDate)
                    .font(.titleSerif)
                    .foregroundStyle(Palette.ink)
                Text("\(renderer.rituName(index: day.yearInfo.rituIndex)) · \(day.yearInfo.ayana)")
                    .font(.bodySans(13.5))
                    .foregroundStyle(Palette.inkMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("VS \(day.displayedVikramSamvat)")
                    .font(.bodySans(14).weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
                masaBadge
            }
        }
        .padding(.bottom, 26)
        .accessibilityElement(children: .combine)
    }

    private var masaBadge: some View {
        HStack(spacing: 6) {
            Text(displayedMasaName)
            if day.masa.isAdhika {
                Text("Adhika")
                    .foregroundStyle(Palette.festival)
            }
            if day.masa.isKshaya {
                Text("Kshaya")
                    .foregroundStyle(Palette.inauspicious)
            }
        }
        .font(.tagSans)
        .foregroundStyle(Palette.inkSecondary)
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
        VStack(alignment: .leading, spacing: 6) {
            if day.sunNeverRises {
                Text("Sun does not rise today at this location.")
                    .font(.bodySans(13.5))
                    .foregroundStyle(Palette.inkMuted)
            }
            if day.sunNeverSets {
                Text("Sun does not set today at this location.")
                    .font(.bodySans(13.5))
                    .foregroundStyle(Palette.inkMuted)
            }
        }
        .padding(.bottom, 20)
    }

    private var festivalsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader("Festivals & Vrats")
                .padding(.bottom, 14)
            ForEach(Array(festivalsWithContent.enumerated()), id: \.element.0.id) { i, pair in
                let (f, content) = pair
                VStack(spacing: 0) {
                    NavigationLink(destination: FestivalDetailView(content: content)) {
                        HStack(alignment: .firstTextBaseline) {
                            AccentDot(color: f.type == .vrat ? Palette.auspicious : Palette.festival)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(f.name)
                                    .font(.rowSerif)
                                    .foregroundStyle(Palette.inkStrong)
                                if let tagline = content.entry.tagline {
                                    Text(tagline)
                                        .font(.tagSans)
                                        .foregroundStyle(Palette.inkFaint)
                                }
                            }
                            Spacer()
                            Text(f.type.rawValue.capitalized)
                                .font(.tagSans)
                                .foregroundStyle(Palette.inkMuted)
                        }
                        .padding(.vertical, 11)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(f.name), \(f.type.rawValue)")
                    }
                    .buttonStyle(.plain)
                    if i < festivalsWithContent.count - 1 {
                        HairlineDivider(opacity: 0.6)
                    }
                }
            }
        }
        .padding(.bottom, 28)
    }

    private var sunMoonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader("Sun & Moon")
                .padding(.bottom, 14)
            timingRow(label: "Sunrise", value: day.timings.sunrise)
            HairlineDivider(opacity: 0.6)
            timingRow(label: "Sunset", value: day.timings.sunset)
            HairlineDivider(opacity: 0.6)
            timingRow(label: "Moonrise", value: day.timings.moonrise)
            HairlineDivider(opacity: 0.6)
            timingRow(label: "Moonset", value: day.timings.moonset)
        }
        .padding(.bottom, 28)
    }

    private var fiveLimbsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader("Panchang")
                .padding(.bottom, 14)
            limbRow(label: "Tithi",
                    value: "\(renderer.paksha(day.tithi.paksha)) \(renderer.tithiName(index: day.tithi.index))",
                    ends: day.tithi.endJulianDay)
            HairlineDivider(opacity: 0.6)
            limbRow(label: "Vara", value: renderer.varaName(index: day.vara.index), ends: nil)
            HairlineDivider(opacity: 0.6)
            limbRow(label: "Nakshatra",
                    value: renderer.nakshatraName(index: day.nakshatra.index),
                    ends: day.nakshatra.endJulianDay)
            HairlineDivider(opacity: 0.6)
            limbRow(label: "Yoga",
                    value: renderer.yogaName(index: day.yoga.index),
                    ends: day.yoga.endJulianDay)
            HairlineDivider(opacity: 0.6)
            limbRow(label: "Karana",
                    value: renderer.karanaName(halfTithiIndex: day.karana.index),
                    ends: day.karana.endJulianDay)
        }
        .padding(.bottom, 28)
    }

    private var monthYearSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader("Calendar")
                .padding(.bottom, 14)
            calendarRow("Masa (Amanta)",
                        renderer.masaName(amantaIndex: day.masa.amantaIndex)
                            + (day.masa.isAdhika ? " (Adhika)" : ""))
            HairlineDivider(opacity: 0.6)
            calendarRow("Masa (Purnimanta)",
                        renderer.masaName(amantaIndex: day.masa.purnimantaIndex)
                            + (day.masa.isAdhika ? " (Adhika)" : ""))
            HairlineDivider(opacity: 0.6)
            calendarRow("Vikram Samvat (North Indian)", "\(day.yearInfo.vikramSamvatChaitradi)")
            HairlineDivider(opacity: 0.6)
            calendarRow("Vikram Samvat (Gujarati)", "\(day.yearInfo.vikramSamvatKartikadi)")
            HairlineDivider(opacity: 0.6)
            calendarRow("Season (Ritu)", renderer.rituName(index: day.yearInfo.rituIndex))
            HairlineDivider(opacity: 0.6)
            calendarRow("Ayana", day.yearInfo.ayana)
        }
        .padding(.bottom, 28)
    }

    private var muhurtaSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            EditorialSectionHeader("Muhurtas")
                .padding(.bottom, 14)
            muhurtaRow(label: "Brahma Muhurta", window: day.muhurtas.brahmaMuhurta, inauspicious: false)
            HairlineDivider(opacity: 0.6)
            muhurtaRow(label: "Abhijit", window: day.muhurtas.abhijit, inauspicious: false)
            HairlineDivider(opacity: 0.6)
            muhurtaRow(label: "Rahu Kalam", window: day.muhurtas.rahuKalam, inauspicious: true)
            HairlineDivider(opacity: 0.6)
            muhurtaRow(label: "Yamaganda", window: day.muhurtas.yamaganda, inauspicious: true)
            HairlineDivider(opacity: 0.6)
            muhurtaRow(label: "Gulika Kalam", window: day.muhurtas.gulika, inauspicious: true)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Row helpers

    private func timingRow(label: String, value: Double?) -> some View {
        AlmanacRow(label: label, value: value.map { formatTime($0) } ?? "–")
            .padding(.vertical, 11)
            .accessibilityLabel("\(label): \(value.map { formatTime($0) } ?? "not available")")
    }

    private func limbRow(label: String, value: String, ends: Double?) -> some View {
        AlmanacRow(label: label, value: value, detail: ends.map { "ends \(formatTime($0))" })
            .padding(.vertical, 11)
            .accessibilityLabel("\(label): \(value)\(ends.map { ", ends \(formatTime($0))" } ?? "")")
    }

    private func calendarRow(_ label: String, _ value: String) -> some View {
        AlmanacRow(label: label, value: value)
            .padding(.vertical, 11)
    }

    private func muhurtaRow(label: String, window: MuhurtaWindow, inauspicious: Bool) -> some View {
        let value: String
        if let s = window.start, let e = window.end {
            value = "\(formatTime(s)) – \(formatTime(e))"
        } else {
            value = "–"
        }
        return AlmanacRow(label: label, value: value,
                           dotColor: inauspicious ? Palette.inauspicious : Palette.auspicious)
            .padding(.vertical, 11)
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
