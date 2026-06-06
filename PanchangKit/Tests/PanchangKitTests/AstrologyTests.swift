import Testing
import Foundation
@testable import PanchangKit

/// M2 astrology engine: structural invariants (synthetic ephemeris) plus a real-SwiftAA spot
/// check against Swiss-Ephemeris reference values. The full parametrised reference gate lives
/// in M2ReferenceTests; this file proves the derivation and the SwiftAA wiring.
struct AstrologyTests {

    // MARK: - Structural invariants (deterministic, no SwiftAA)

    private func syntheticAstrology() -> Astrology {
        // Sun ~1°/day, Moon ~13.18°/day, from a fixed reference; ConstantAyanamsa 24°.
        let eph = LinearEphemeris(jd0: 2_460_000, sun0: 100, moon0: 200, sunRate: 0.9856, moonRate: 13.176)
        return Astrology(ephemeris: eph, ayanamsa: ConstantAyanamsa(degrees: 24))
    }

    @Test func ninePlanetsPlusLagna() {
        let p = syntheticAstrology().positions(julianDay: 2_460_100, location: GeoLocation(latitude: 19, longitude: 73, timeZoneIdentifier: "Asia/Kolkata"))
        #expect(p.planets.count == 9)
        #expect(p.planets.map(\.id) == ["sun","moon","mars","mercury","jupiter","venus","saturn","rahu","ketu"])
        #expect(p.lagna.id == "lagna")
    }

    @Test func indicesInValidRanges() {
        let p = syntheticAstrology().positions(julianDay: 2_460_100, location: GeoLocation(latitude: 19, longitude: 73, timeZoneIdentifier: "Asia/Kolkata"))
        for planet in p.planets + [p.lagna] {
            #expect(planet.longitude >= 0 && planet.longitude < 360)
            #expect(planet.rashi >= 0 && planet.rashi < 12)
            #expect(planet.nakshatra >= 0 && planet.nakshatra < 27)
            #expect(planet.navamshaRashi >= 0 && planet.navamshaRashi < 12)
            #expect(planet.rashiName == PanchangNames.rashi[planet.rashi])
        }
    }

    @Test func rahuKetuOppositeAndAlwaysRetrograde() {
        let p = syntheticAstrology().positions(julianDay: 2_460_100, location: GeoLocation(latitude: 19, longitude: 73, timeZoneIdentifier: "Asia/Kolkata"))
        let rahu = p.planets.first { $0.id == "rahu" }!
        let ketu = p.planets.first { $0.id == "ketu" }!
        #expect(abs(AngleMath.normalize180(ketu.longitude - rahu.longitude) - 180) < 1e-6 || abs(AngleMath.normalize180(rahu.longitude - ketu.longitude) - 180) < 1e-6)
        #expect(rahu.isRetrograde)
        #expect(ketu.isRetrograde)
    }

    @Test func sunMoonNeverRetrograde() {
        let p = syntheticAstrology().positions(julianDay: 2_460_100, location: GeoLocation(latitude: 19, longitude: 73, timeZoneIdentifier: "Asia/Kolkata"))
        #expect(!p.planets.first { $0.id == "sun" }!.isRetrograde)
        #expect(!p.planets.first { $0.id == "moon" }!.isRetrograde)
    }

    // MARK: - Navamsha anchors (classical movable/fixed/dual rule, via continuous formula)

    @Test func navamshaAnchors() {
        #expect(Navamsha.rashi(siderealLongitude: 0.0) == 0)    // Aries 0° → Aries (movable: same)
        #expect(Navamsha.rashi(siderealLongitude: 30.0) == 9)   // Taurus 0° → Capricorn (fixed: 9th)
        #expect(Navamsha.rashi(siderealLongitude: 60.0) == 6)   // Gemini 0° → Libra (dual: 5th)
        #expect(Navamsha.rashi(siderealLongitude: 359.999) == 11) // Pisces last navamsha → Pisces
    }

    // MARK: - Real SwiftAA spot check vs Swiss Ephemeris (single case, proves the wiring)

    /// Swiss-Ephemeris reference for 2024-08-26 05:30 UT, San Jose (JD 2460548.72917).
    /// Planets within ±0°05′ (3′); Lagna within ±1°. Mercury & Saturn retrograde.
    @Test func swiftAAMatchesSwissEphemeris() {
        let jd = 2460548.72917
        let loc = GeoLocation(latitude: 37.3382, longitude: -121.8863, timeZoneIdentifier: "America/Los_Angeles")
        let p = Astrology().positions(julianDay: jd, location: loc)

        let expected: [String: Double] = [
            "sun": 129.2771, "moon": 37.1926, "mars": 59.8844, "mercury": 117.6702,
            "jupiter": 54.1178, "venus": 151.7217, "saturn": 322.8055,
            "rahu": 344.0618, "ketu": 164.0618,
        ]
        for planet in p.planets {
            let exp = expected[planet.id]!
            let diff = abs(AngleMath.normalize180(planet.longitude - exp))
            #expect(diff <= 5.0 / 60.0, "\(planet.id) off by \(diff * 60)′ (got \(planet.longitude), exp \(exp))")
        }
        #expect(p.planets.first { $0.id == "mercury" }!.isRetrograde, "Mercury should be retrograde")
        #expect(p.planets.first { $0.id == "saturn" }!.isRetrograde, "Saturn should be retrograde")
        #expect(!p.planets.first { $0.id == "venus" }!.isRetrograde, "Venus should be direct")

        let lagnaDiff = abs(AngleMath.normalize180(p.lagna.longitude - 15.2766))
        #expect(lagnaDiff <= 1.0, "Lagna off by \(lagnaDiff)° (got \(p.lagna.longitude), exp 15.2766)")
    }
}
