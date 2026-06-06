import Testing
import Foundation
@testable import PanchangKit

/// Vimshottari dasha: structural invariants (lord order, period sums, current-flag uniqueness)
/// over the pure calculator, plus a real-SwiftAA structural check of the captured birth case.
/// Absolute dates are NOT asserted against drikpanchang — its Lahiri constant differs from
/// SE/SwiftAA by ~0.142°, shifting boundaries ~5 days (see m2_astrology_vectors.json).
struct VimshottariTests {

    private let calc = VimshottariCalculator()

    /// A fixed birth JD and a query date 10 years later, both deterministic.
    private let birthJD = 2_446_482.0   // ~1986-02-20
    private func asOf(yearsAfterBirth y: Double) -> Date {
        JulianDate.date(from: birthJD + y * 365.25)
    }

    @Test func nineMahadashasInCyclicLordOrder() {
        // Moon at 5° → Ashwini (nakshatra 0) → start lord Ketu.
        let d = calc.compute(birthJulianDay: birthJD, moonLongitudeSidereal: 5.0, asOf: asOf(yearsAfterBirth: 1))
        #expect(d.mahadashas.count == 9)
        let order = d.mahadashas.map(\.planet)
        #expect(order == ["Ketu","Venus","Sun","Moon","Mars","Rahu","Jupiter","Saturn","Mercury"])
    }

    @Test func startLordTracksNakshatra() {
        // Each nakshatra's lord = vimshottariLords[nakshatra % 9].
        func startLord(moonLon: Double) -> String {
            calc.compute(birthJulianDay: birthJD, moonLongitudeSidereal: moonLon, asOf: asOf(yearsAfterBirth: 1)).mahadashas[0].planet
        }
        #expect(startLord(moonLon: 5.0) == "Ketu")     // Ashwini (0)
        #expect(startLord(moonLon: 20.0) == "Venus")   // Bharani (1)
        #expect(startLord(moonLon: 35.0) == "Sun")     // Krittika (2)
        #expect(startLord(moonLon: 45.0) == "Moon")    // Rohini (3)
        #expect(startLord(moonLon: 130.0) == "Ketu")   // Magha (9) → 9%9=0
    }

    @Test func mahadashasSpanExactly120Years() {
        let d = calc.compute(birthJulianDay: birthJD, moonLongitudeSidereal: 73.4, asOf: asOf(yearsAfterBirth: 1))
        let firstStart = JulianDate.julianDay(from: d.mahadashas.first!.start)
        let lastEnd = JulianDate.julianDay(from: d.mahadashas.last!.end)
        let spanDays = lastEnd - firstStart
        #expect(abs(spanDays - 120 * 365.25) < 1.0, "span \(spanDays) days != 120 yr")
    }

    @Test func exactlyOneCurrentMahadasha() {
        for y in stride(from: 0.5, through: 110.0, by: 7.3) {
            let d = calc.compute(birthJulianDay: birthJD, moonLongitudeSidereal: 73.4, asOf: asOf(yearsAfterBirth: y))
            #expect(d.mahadashas.filter(\.isCurrent).count == 1, "at +\(y)y")
        }
    }

    @Test func firstMahadashaStartsBeforeBirthByElapsed() {
        // Moon at exactly the midpoint of a nakshatra → half the lord's period already elapsed.
        // Bharani spans [13.333, 26.667); midpoint 20.0 → Venus (20 yr), 10 yr elapsed.
        let d = calc.compute(birthJulianDay: birthJD, moonLongitudeSidereal: 20.0, asOf: asOf(yearsAfterBirth: 1))
        let firstStart = JulianDate.julianDay(from: d.mahadashas[0].start)
        let elapsedDays = birthJD - firstStart
        #expect(abs(elapsedDays - 10 * 365.25) < 1.0, "elapsed \(elapsedDays) days != 10 yr")
    }

    @Test func antardashasOfCurrentMahadashaSumToItsSpan() {
        let d = calc.compute(birthJulianDay: birthJD, moonLongitudeSidereal: 73.4, asOf: asOf(yearsAfterBirth: 25))
        let md = d.mahadashas.first(where: \.isCurrent)!
        #expect(d.currentAntardashas.count == 9)
        #expect(d.currentAntardashas.first!.planet == md.planet, "first antardasha lord = mahadasha lord")
        #expect(d.currentAntardashas.filter(\.isCurrent).count == 1)
        let adStart = JulianDate.julianDay(from: d.currentAntardashas.first!.start)
        let adEnd = JulianDate.julianDay(from: d.currentAntardashas.last!.end)
        let mdStart = JulianDate.julianDay(from: md.start)
        let mdEnd = JulianDate.julianDay(from: md.end)
        #expect(abs(adStart - mdStart) < 1e-6 && abs(adEnd - mdEnd) < 1e-3, "antardashas must tile the mahadasha")
    }

    @Test func deterministicForFixedInputs() {
        let a = calc.compute(birthJulianDay: birthJD, moonLongitudeSidereal: 73.4, asOf: asOf(yearsAfterBirth: 25))
        let b = calc.compute(birthJulianDay: birthJD, moonLongitudeSidereal: 73.4, asOf: asOf(yearsAfterBirth: 25))
        #expect(a.mahadashas.map(\.id) == b.mahadashas.map(\.id))
        #expect(a.mahadashas.map { $0.start } == b.mahadashas.map { $0.start })
    }

    /// Real birth from the fixture (1986-02-20 08:03 IST, Vadodara) via SwiftAA. Structural
    /// only: the Moon falls in Ardra → start lord Rahu, and the cycle order matches drikpanchang.
    @Test func capturedBirthCaseStructure() {
        let birth = JulianDate.julianDay(year: 1986, month: 2, day: 20, hour: 8, minute: 3, timeZone: TimeZone(identifier: "Asia/Kolkata")!)!
        let d = Astrology().dasha(birth: JulianDate.date(from: birth), asOf: JulianDate.date(from: 2_461_000.0))
        #expect(d.mahadashas[0].planet == "Rahu", "born in Ardra → Rahu mahadasha first")
        #expect(d.mahadashas.map(\.planet) == ["Rahu","Jupiter","Saturn","Mercury","Ketu","Venus","Sun","Moon","Mars"])
    }
}
