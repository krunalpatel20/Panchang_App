import Testing
import Foundation
@testable import PanchangKit

/// Not an assertion suite — prints computed vs. expected for the trustworthy golden cases so
/// we can measure real engine accuracy before locking in tolerances.
struct ExplorationTests {
    private func hm(_ jd: Double?, _ tz: TimeZone) -> String {
        guard let jd else { return "--:--" }
        let c = JulianDate.components(julianDay: jd, timeZone: tz)
        return String(format: "%02d:%02d (%@)", c.hour ?? 0, c.minute ?? 0,
                      String(format: "%02d/%02d", c.month ?? 0, c.day ?? 0))
    }

    @Test func dumpWashingtonDC() {
        let loc = GeoLocation(latitude: 38.895, longitude: -77.036, timeZoneIdentifier: "America/New_York")
        let tz = loc.timeZone
        let day = Panchang().compute(year: 2026, month: 5, day: 28, location: loc, config: .gujaratiWestern)
        print("=== Washington DC 2026-05-28 (expected: WDC worked example) ===")
        print("sunrise   \(hm(day.timings.sunrise, tz))   expected 05:46")
        print("sunset    \(hm(day.timings.sunset, tz))   expected 20:25")
        print("moonrise  \(hm(day.timings.moonrise, tz))   expected 18:21")
        print("moonset   \(hm(day.timings.moonset, tz))   expected 04:10 +1")
        print("tithi     \(day.tithi.name) \(day.tithi.paksha.rawValue) ends \(hm(day.tithi.endJulianDay, tz))   expected Trayodashi Shukla 00:20 +1")
        print("nakshatra \(day.nakshatra.name) ends \(hm(day.nakshatra.endJulianDay, tz))   expected Swati 01:08 +1")
        print("yoga      \(day.yoga.name) ends \(hm(day.yoga.endJulianDay, tz))   expected Variyana 18:25")
        print("karana    \(day.karana.name) ends \(hm(day.karana.endJulianDay, tz))   expected Kaulava 11:21")
        print("vara      \(day.vara.name)   expected Thursday")
        print("masa A    \(day.masa.amantaName)  P \(day.masa.purnimantaName)  adhika \(day.masa.isAdhika)   expected Jyeshtha/Jyeshtha adhika=true")
        print("vikram K  \(day.yearInfo.vikramSamvatKartikadi)  C \(day.yearInfo.vikramSamvatChaitradi)   expected gujarati 2082 vikram 2083")
        print("ritu      \(day.yearInfo.rituName)  ayana \(day.yearInfo.ayana)   expected Grishma Uttarayana")
        print("brahma    \(hm(day.muhurtas.brahmaMuhurta.start, tz))-\(hm(day.muhurtas.brahmaMuhurta.end, tz))   expected 04:31-05:09")
        print("abhijit   \(hm(day.muhurtas.abhijit.start, tz))-\(hm(day.muhurtas.abhijit.end, tz))   expected 12:36-13:35")
        print("rahu      \(hm(day.muhurtas.rahuKalam.start, tz))-\(hm(day.muhurtas.rahuKalam.end, tz))   expected 14:55-16:45")
        print("yamaganda \(hm(day.muhurtas.yamaganda.start, tz))-\(hm(day.muhurtas.yamaganda.end, tz))   expected 05:46-07:36")
        print("gulika    \(hm(day.muhurtas.gulika.start, tz))-\(hm(day.muhurtas.gulika.end, tz))   expected 09:26-11:16")
        print("ayanamsa(2026-05-28) = \(LahiriAyanamsa().value(julianDay: day.timings.sunrise ?? 0))")
    }

    @Test func dumpSanJoseJanmashtami() {
        let loc = GeoLocation(latitude: 37.3382, longitude: -121.8863, timeZoneIdentifier: "America/Los_Angeles")
        let tz = loc.timeZone
        let day = Panchang().compute(year: 2024, month: 8, day: 26, location: loc, config: .gujaratiWestern)
        print("=== San Jose 2024-08-26 (Janmashtami) ===")
        print("sunrise   \(hm(day.timings.sunrise, tz))   expected 06:34")
        print("sunset    \(hm(day.timings.sunset, tz))   expected 19:44")
        print("tithi     \(day.tithi.name) \(day.tithi.paksha.rawValue) ends \(hm(day.tithi.endJulianDay, tz))   expected Ashtami Krishna 13:49")
        print("nakshatra \(day.nakshatra.name) ends \(hm(day.nakshatra.endJulianDay, tz))   expected Rohini 03:08 +1")
        print("yoga      \(day.yoga.name) ends \(hm(day.yoga.endJulianDay, tz))   expected Vyaghata 09:47")
        print("karana    \(day.karana.name) ends \(hm(day.karana.endJulianDay, tz))   expected Kaulava 13:49")
        print("masa A    \(day.masa.amantaName)  P \(day.masa.purnimantaName)   expected Shravana/Bhadrapada")
        print("vikram K  \(day.yearInfo.vikramSamvatKartikadi)  C \(day.yearInfo.vikramSamvatChaitradi)   expected gujarati 2080 vikram 2081")
    }

    @Test func dumpEdisonNewYear() {
        let loc = GeoLocation(latitude: 40.5187, longitude: -74.4121, timeZoneIdentifier: "America/New_York")
        let tz = loc.timeZone
        let day = Panchang().compute(year: 2024, month: 11, day: 2, location: loc, config: .gujaratiWestern)
        print("=== Edison NJ 2024-11-02 (Gujarati New Year) ===")
        print("sunrise   \(hm(day.timings.sunrise, tz))   expected 07:40")
        print("sunset    \(hm(day.timings.sunset, tz))   expected 18:57")
        print("tithi     \(day.tithi.name) \(day.tithi.paksha.rawValue) ends \(hm(day.tithi.endJulianDay, tz))   expected Pratipada Shukla full_night")
        print("nakshatra \(day.nakshatra.name) ends \(hm(day.nakshatra.endJulianDay, tz))   expected Chitra 12:29")
        print("masa A    \(day.masa.amantaName)   expected Kartika")
        print("vikram K  \(day.yearInfo.vikramSamvatKartikadi)  C \(day.yearInfo.vikramSamvatChaitradi)   expected gujarati 2082 vikram 2082 (drik); rule-based may read 2081")
    }
}
