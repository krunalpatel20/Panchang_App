import Testing
import Foundation
@testable import PanchangKit

/// A deterministic ephemeris: Sun and Moon advance at constant rates from a reference JD, so
/// limb values and end times can be asserted exactly without depending on SwiftAA (SPEC §3.3:
/// keep engine tests deterministic with fixed JD inputs).
struct LinearEphemeris: Ephemeris {
    var jd0: Double
    var sun0: Double
    var moon0: Double
    var sunRate: Double   // deg/day
    var moonRate: Double  // deg/day

    func sunLongitude(julianDay: Double) -> Double {
        AngleMath.normalize360(sun0 + sunRate * (julianDay - jd0))
    }
    func moonLongitude(julianDay: Double) -> Double {
        AngleMath.normalize360(moon0 + moonRate * (julianDay - jd0))
    }
    func riseTransitSet(body: Body, anchorJulianDay: Double, location: GeoLocation) -> RiseSet {
        // Fixed 06:00/18:00-ish placeholders; the structural tests don't exercise timings.
        RiseSet(rise: anchorJulianDay - 0.25, transit: anchorJulianDay, set: anchorJulianDay + 0.25)
    }

    // M2 additions. Synthetic linear motion per graha so position/dasha tests are deterministic.
    func longitude(of graha: Graha, julianDay: Double) -> Double {
        switch graha {
        case .sun:  return sunLongitude(julianDay: julianDay)
        case .moon: return moonLongitude(julianDay: julianDay)
        default:
            let base = Double(Graha.allCases.firstIndex(of: graha) ?? 0) * 40.0
            return AngleMath.normalize360(base + 0.5 * (julianDay - jd0))
        }
    }
    // Mean node regresses ~0.0529°/day from a fixed reference (always retrograde).
    func lunarNodeLongitude(julianDay: Double) -> Double {
        AngleMath.normalize360(100.0 - 0.0529539 * (julianDay - jd0))
    }
    func greenwichApparentSiderealTime(julianDay: Double) -> Double {
        AngleMath.normalize360(280.46 + 360.98564736629 * (julianDay - 2451545.0))
    }
    func obliquityOfEcliptic(julianDay: Double) -> Double { 23.4392911 }
}

struct ConstantAyanamsa: Ayanamsa {
    let degrees: Double
    func value(julianDay: Double) -> Double { degrees }
}

struct StructuralTests {
    private let jd0 = 2_460_000.0

    @Test func tithiNamePakshaConsistency() {
        for i in 0..<30 {
            let name = PanchangNames.tithi[i]
            #expect(!name.isEmpty)
        }
        #expect(PanchangNames.tithi[0] == "Pratipada")
        #expect(PanchangNames.tithi[14] == "Purnima")
        #expect(PanchangNames.tithi[29] == "Amavasya")
    }

    @Test func karanaSequenceMatchesClassicalScheme() {
        // 0 = Kimstughna, 1…56 cycle the 7 movable, 57/58/59 = Shakuni/Chatushpada/Naga.
        #expect(PanchangNames.karana(halfTithiIndex: 0) == "Kimstughna")
        #expect(PanchangNames.karana(halfTithiIndex: 1) == "Bava")
        #expect(PanchangNames.karana(halfTithiIndex: 7) == "Vishti")
        #expect(PanchangNames.karana(halfTithiIndex: 8) == "Bava")
        #expect(PanchangNames.karana(halfTithiIndex: 57) == "Shakuni")
        #expect(PanchangNames.karana(halfTithiIndex: 58) == "Chatushpada")
        #expect(PanchangNames.karana(halfTithiIndex: 59) == "Naga")
    }

    @Test func tithiIndexAndEndTimeAreExactUnderLinearMotion() {
        // Moon−Sun start at 30° elongation → tithi index 2 (Tritiya), arc edge at 36°.
        let eph = LinearEphemeris(jd0: jd0, sun0: 0, moon0: 30, sunRate: 1.0, moonRate: 13.2)
        let limbs = FiveLimbs(ephemeris: eph, ayanamsa: ConstantAyanamsa(degrees: 24))
        let tithi = limbs.tithi(atSunrise: jd0)
        #expect(tithi.index == 2)
        #expect(tithi.name == "Tritiya")
        #expect(tithi.paksha == .shukla)
        // Elongation grows at (13.2 − 1.0) = 12.2°/day; needs 6° more to reach 36°.
        let expectedEnd = jd0 + 6.0 / 12.2
        #expect(abs(tithi.endJulianDay - expectedEnd) < 1.0 / 1440.0) // within 1 minute
    }

    @Test func nakshatraUsesSiderealMoon() {
        // Tropical Moon 100°, ayanamsa 24° → sidereal 76° → nakshatra index floor(76/13.333)=5 (Ardra).
        let eph = LinearEphemeris(jd0: jd0, sun0: 0, moon0: 100, sunRate: 1.0, moonRate: 13.2)
        let limbs = FiveLimbs(ephemeris: eph, ayanamsa: ConstantAyanamsa(degrees: 24))
        let nak = limbs.nakshatra(atSunrise: jd0)
        #expect(nak.index == 5)
        #expect(nak.name == "Ardra")
    }

    @Test func segmentCrossingHandlesWrapAt360() {
        // Elongation starts at 357° (Amavasya, index 29); end target is 360° ≡ new moon.
        let eph = LinearEphemeris(jd0: jd0, sun0: 0, moon0: 357, sunRate: 1.0, moonRate: 13.2)
        let limbs = FiveLimbs(ephemeris: eph, ayanamsa: ConstantAyanamsa(degrees: 24))
        let tithi = limbs.tithi(atSunrise: jd0)
        #expect(tithi.index == 29)
        #expect(tithi.name == "Amavasya")
        let expectedEnd = jd0 + 3.0 / 12.2 // 3° to reach 360°
        #expect(abs(tithi.endJulianDay - expectedEnd) < 1.0 / 1440.0)
    }
}
