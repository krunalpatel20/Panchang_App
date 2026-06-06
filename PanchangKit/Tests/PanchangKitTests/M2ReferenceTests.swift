import Testing
import Foundation
@testable import PanchangKit

/// Phase-D reference gate: the engine's sidereal positions, lagna, and dasha structure against
/// `m2_astrology_vectors.json`. Planetary/lagna references come from Swiss Ephemeris (an
/// independent backend); the dasha case is structural only (drikpanchang's Lahiri differs).
struct M2ReferenceTests {

    // MARK: Fixture model

    private struct Fixture: Decodable {
        let planetary: [PlanetaryCase]
        let dasha: [DashaCase]
    }
    struct PlanetVec: Decodable, Sendable { let lon: Double; let retro: Bool }
    struct PlanetaryCase: Decodable, Sendable {
        let id: String
        let jd_utc: Double
        let lat, lon: Double
        let tz: String
        let lagna_sidereal_deg: Double
        let planets: [String: PlanetVec]
    }
    private struct MahaRef: Decodable { let lord: String }
    private struct DashaCase: Decodable {
        let id: String
        let birth_iso: String
        let tz: String
        let lat, lon: Double
        let start_lord: String
        let mahadashas: [MahaRef]
    }

    private static func load() throws -> Fixture {
        let url = Bundle.module.url(forResource: "m2_astrology_vectors", withExtension: "json")
            ?? Bundle.module.url(forResource: "m2_astrology_vectors", withExtension: "json", subdirectory: "Fixtures")
        guard let url else { Issue.record("m2_astrology_vectors.json not in test bundle"); throw CocoaError(.fileNoSuchFile) }
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    private static func planetaryCases() -> [PlanetaryCase] { (try? load())?.planetary ?? [] }

    // MARK: Planetary + lagna gate (±0°05′ planets, ±1° lagna, retrograde flags exact)

    @Test(arguments: planetaryCases())
    func planetaryPositionsMatchSwissEphemeris(c: PlanetaryCase) {
        let loc = GeoLocation(latitude: c.lat, longitude: c.lon, timeZoneIdentifier: c.tz)
        let p = Astrology().positions(julianDay: c.jd_utc, location: loc)

        for planet in p.planets {
            guard let ref = c.planets[planet.id] else { Issue.record("\(c.id): no ref for \(planet.id)"); continue }
            let diffArcmin = abs(AngleMath.normalize180(planet.longitude - ref.lon)) * 60
            #expect(diffArcmin <= 3.0, "\(c.id) \(planet.id) off by \(diffArcmin)′ (got \(planet.longitude), exp \(ref.lon))")
            #expect(planet.isRetrograde == ref.retro, "\(c.id) \(planet.id) retro \(planet.isRetrograde) != \(ref.retro)")
        }
        let lagnaDiff = abs(AngleMath.normalize180(p.lagna.longitude - c.lagna_sidereal_deg))
        #expect(lagnaDiff <= 1.0, "\(c.id) lagna off by \(lagnaDiff)° (got \(p.lagna.longitude), exp \(c.lagna_sidereal_deg))")
    }

    // MARK: Dasha structural gate (lord order; absolute dates NOT gated — ayanamsa divergence)

    @Test func dashaLordSequenceMatchesReference() throws {
        let f = try Self.load()
        guard let d = f.dasha.first else { Issue.record("no dasha case"); return }
        let birth = parseISO(d.birth_iso, tz: d.tz)
        let result = Astrology().dasha(birth: birth, asOf: JulianDate.date(from: 2_461_000.0))
        #expect(result.mahadashas.first?.planet == d.start_lord, "start lord \(result.mahadashas.first?.planet ?? "nil") != \(d.start_lord)")
        #expect(result.mahadashas.map(\.planet) == d.mahadashas.map(\.lord), "mahadasha lord sequence mismatch")
    }

    private func parseISO(_ s: String, tz: String) -> Date {
        // "1986-02-20T08:03:00"
        let parts = s.split(separator: "T")
        let ymd = parts[0].split(separator: "-").map { Int($0)! }
        let hms = parts.count > 1 ? parts[1].split(separator: ":").map { Int($0)! } : [0, 0, 0]
        let jd = JulianDate.julianDay(year: ymd[0], month: ymd[1], day: ymd[2],
                                      hour: hms[0], minute: hms.count > 1 ? hms[1] : 0,
                                      timeZone: TimeZone(identifier: tz)!)!
        return JulianDate.date(from: jd)
    }
}
