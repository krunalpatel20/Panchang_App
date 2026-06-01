import Testing
import Foundation
@testable import PanchangKit

/// SPEC §8/§13: switching the tradition preset is a labeling transform. It must change the
/// Krishna-paksha month label and the displayed Samvat year, while the underlying astronomy
/// (tithi, nakshatra, …) is identical. (Festival-date invariance is verified in M5.)
struct PresetTests {
    private let sanJose = GeoLocation(latitude: 37.3382, longitude: -121.8863, timeZoneIdentifier: "America/Los_Angeles")

    private func compute(_ y: Int, _ m: Int, _ d: Int, _ config: CalendarConfig, _ loc: GeoLocation) -> PanchangDay {
        Panchang().compute(year: y, month: m, day: d, location: loc, config: config)
    }

    @Test func krishnaPakshaMonthLabelShiftsBetweenPresets() {
        // Janmashtami 2024 (Krishna Ashtami): Amanta = Shravana, Purnimanta = Bhadrapada.
        let guj = compute(2024, 8, 26, .gujaratiWestern, sanJose)
        let north = compute(2024, 8, 26, .northIndian, sanJose)

        #expect(guj.tithi.paksha == .krishna)
        // Astronomy identical across presets.
        #expect(guj.tithi.index == north.tithi.index)
        #expect(guj.nakshatra.index == north.nakshatra.index)
        // Krishna-paksha label shifts forward by one month under Purnimanta.
        #expect(guj.displayedMasaName == "Shravana")
        #expect(north.displayedMasaName == "Bhadrapada")
    }

    @Test func shuklaPakshaMonthLabelIsIdenticalAcrossPresets() {
        // Adhika Jyeshtha Shukla Trayodashi (WDC worked example date) — Shukla labels match.
        let wdc = GeoLocation(latitude: 38.895, longitude: -77.036, timeZoneIdentifier: "America/New_York")
        let guj = compute(2026, 5, 28, .gujaratiWestern, wdc)
        let north = compute(2026, 5, 28, .northIndian, wdc)
        #expect(guj.tithi.paksha == .shukla)
        #expect(guj.displayedMasaName == north.displayedMasaName)
        #expect(guj.displayedMasaName == "Jyeshtha")
    }

    @Test func gujaratiSamvatTrailsVikramByOneBetweenChaitraAndKartik() {
        // SPEC §13: for a date in the Chaitra→Kartik window, the Gujarati (Kartikadi) year is
        // one less than the North (Chaitradi) year. WDC adhika-Jyeshtha (May) is in-window.
        let wdc = GeoLocation(latitude: 38.895, longitude: -77.036, timeZoneIdentifier: "America/New_York")
        let day = compute(2026, 5, 28, .gujaratiWestern, wdc)
        #expect(day.yearInfo.vikramSamvatKartikadi == day.yearInfo.vikramSamvatChaitradi - 1)
        // Matches the worked example's published values.
        #expect(day.yearInfo.vikramSamvatChaitradi == 2083)
        #expect(day.yearInfo.vikramSamvatKartikadi == 2082)
    }
}
