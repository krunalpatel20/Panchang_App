import Testing
import Foundation
@testable import PanchangKit

/// SPEC §13 acceptance criterion: tithi/karana are computed from Moon−Sun elongation
/// **without** an ayanamsa term (it cancels), so they must be invariant to the ayanamsa
/// choice; nakshatra/yoga **with** it, so they must change. This catches the most common
/// derivation error (subtracting ayanamsa twice, or not at all).
struct InvarianceTests {
    private let location = GeoLocation(latitude: 38.895, longitude: -77.036, timeZoneIdentifier: "America/New_York")

    private func day(ayanamsa: Ayanamsa) -> PanchangDay {
        Panchang(ephemeris: SwiftAAEphemeris(), ayanamsa: ayanamsa)
            .compute(year: 2026, month: 5, day: 28, location: location, config: .gujaratiWestern)
    }

    @Test func tithiAndKaranaAreInvariantToAyanamsa() {
        // Two wildly different ayanamsas: 0° and 50°.
        let a = day(ayanamsa: ConstantAyanamsa(degrees: 0))
        let b = day(ayanamsa: ConstantAyanamsa(degrees: 50))

        #expect(a.tithi.index == b.tithi.index)
        #expect(a.tithi.paksha == b.tithi.paksha)
        #expect(abs(a.tithi.endJulianDay - b.tithi.endJulianDay) < 1.0 / 86400.0)
        #expect(a.karana.index == b.karana.index)
        #expect(abs(a.karana.endJulianDay - b.karana.endJulianDay) < 1.0 / 86400.0)
    }

    @Test func nakshatraAndYogaChangeWithAyanamsa() {
        // 50° shifts the sidereal Moon by 50/13.333 ≈ 3.75 nakshatras → guaranteed different.
        let a = day(ayanamsa: ConstantAyanamsa(degrees: 0))
        let b = day(ayanamsa: ConstantAyanamsa(degrees: 50))

        #expect(a.nakshatra.index != b.nakshatra.index)
        #expect(a.yoga.index != b.yoga.index)
    }
}
