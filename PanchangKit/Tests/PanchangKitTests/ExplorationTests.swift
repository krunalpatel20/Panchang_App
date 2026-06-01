import Testing
import Foundation
@testable import PanchangKit

/// Prints computed vs. expected for all golden cases. Not assertions — used to calibrate
/// tolerances before locking in GoldenVectorTests.
struct ExplorationTests {
    private func hm(_ jd: Double?, _ tz: TimeZone, baseY: Int, baseM: Int, baseD: Int) -> String {
        guard let jd else { return "--:--" }
        let c = JulianDate.components(julianDay: jd, timeZone: tz)
        let d = c.day ?? 0
        let suffix = d != baseD ? " +\(d - baseD)" : ""
        return String(format: "%02d:%02d%@", c.hour ?? 0, c.minute ?? 0, suffix)
    }

    private func loadCases() -> [[String: Any]] {
        let url = Bundle.module.url(forResource: "golden_vectors", withExtension: "json")
            ?? Bundle.module.url(forResource: "golden_vectors", withExtension: "json", subdirectory: "Fixtures")
        guard let url, let data = try? Data(contentsOf: url),
              let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cases = top["cases"] as? [[String: Any]] else { return [] }
        return cases
    }

    private func config(for preset: String) -> CalendarConfig {
        preset == "north_indian" ? .northIndian : .gujaratiWestern
    }

    @Test func dumpAllCases() {
        let cases = loadCases()
        for c in cases {
            guard let exp = c["expected"] as? [String: Any],
                  let dateStr = c["date_iso"] as? String,
                  let locDict = c["location"] as? [String: Any],
                  let lat = locDict["lat"] as? Double,
                  let lon = locDict["lon"] as? Double,
                  let tz = locDict["tz"] as? String else { continue }
            let parts = dateStr.split(separator: "-")
            guard parts.count == 3,
                  let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { continue }
            let id = c["id"] as? String ?? "?"
            let preset = c["preset"] as? String ?? "gujarati_western"
            let loc = GeoLocation(latitude: lat, longitude: lon, timeZoneIdentifier: tz)
            let tzObj = loc.timeZone
            let day = Panchang().compute(year: y, month: m, day: d, location: loc, config: config(for: preset))
            let hm = { (jd: Double?) in self.hm(jd, tzObj, baseY: y, baseM: m, baseD: d) }

            print("[\(id)]")
            print("  sunrise   got=\(hm(day.timings.sunrise))  exp=\(exp["sunrise"] as? String ?? "-")")
            print("  sunset    got=\(hm(day.timings.sunset))   exp=\(exp["sunset"] as? String ?? "-")")
            if let t = exp["tithi"] as? [String: Any] {
                print("  tithi     got=\(day.tithi.name)/\(day.tithi.paksha.rawValue) ends \(hm(day.tithi.endJulianDay))  exp=\(t["name"] as? String ?? "?")/\(t["paksha"] as? String ?? "?") ends \(t["ends"] as? String ?? "?")")
            }
            if let n = exp["nakshatra"] as? [String: Any] {
                print("  nakshatra got=\(day.nakshatra.name) ends \(hm(day.nakshatra.endJulianDay))  exp=\(n["name"] as? String ?? "?") ends \(n["ends"] as? String ?? "?")")
            }
            if let yg = exp["yoga"] as? [String: Any] {
                print("  yoga      got=\(day.yoga.name) ends \(hm(day.yoga.endJulianDay))  exp=\(yg["name"] as? String ?? "?") ends \(yg["ends"] as? String ?? "?")")
            }
            if let k = exp["karana"] as? [String: Any] {
                print("  karana    got=\(day.karana.name) ends \(hm(day.karana.endJulianDay))  exp=\(k["name"] as? String ?? "?") ends \(k["ends"] as? String ?? "?")")
            }
            print("  vara      got=\(day.vara.name)  exp=\(exp["vara"] as? String ?? "?")")
            print("  masa      got=A:\(day.masa.amantaName) P:\(day.masa.purnimantaName) adhika=\(day.masa.isAdhika)  exp=A:\(exp["chandramasa_amanta"] as? String ?? "?") P:\(exp["chandramasa_purnimanta"] as? String ?? "?") adhika=\(exp["adhika"] as? Bool ?? false)")
            print("  samvat    got=K:\(day.yearInfo.vikramSamvatKartikadi) C:\(day.yearInfo.vikramSamvatChaitradi)  exp=gujarati:\(exp["gujarati_samvat"] as? Int ?? 0) vikram:\(exp["vikram_samvat"] as? Int ?? 0)")
            print("  ritu/ayana got=\(day.yearInfo.rituName)/\(day.yearInfo.ayana)  exp=\(exp["ritu"] as? String ?? "?")/\(exp["ayana"] as? String ?? "?")")
            print("  rahu      got=\(hm(day.muhurtas.rahuKalam.start))-\(hm(day.muhurtas.rahuKalam.end))  exp=\(exp["rahu_kalam"] as? String ?? "?")")
            print("  brahma    got=\(hm(day.muhurtas.brahmaMuhurta.start))-\(hm(day.muhurtas.brahmaMuhurta.end))  exp=\(exp["brahma_muhurta"] as? String ?? "?")")
        }
    }
}
