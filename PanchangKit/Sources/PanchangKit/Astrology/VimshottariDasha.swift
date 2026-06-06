import Foundation

/// Vimshottari dasha — the 120-year planetary period cycle keyed to the Moon's nakshatra at
/// birth. The running mahadasha at birth is the one ruling the janma nakshatra; the fraction of
/// that nakshatra already traversed sets how much of its period is already spent.
public struct VimshottariDasha: Sendable {
    public struct Period: Sendable, Identifiable {
        public let id: String
        public let planet: String
        public let start: Date
        public let end: Date
        public let isCurrent: Bool
    }
    /// The nine mahadashas in sequence. The first may start before birth (the native is born
    /// partway through it), matching how drikpanchang presents the cycle.
    public let mahadashas: [Period]
    /// Antardashas (sub-periods) of whichever mahadasha is current at the query date.
    public let currentAntardashas: [Period]
}

/// Pure dasha arithmetic. All spans use a 365.25-day year and are computed in Julian Day, then
/// converted to `Date` only at the period boundaries — long spans done in `Date`/`Calendar`
/// arithmetic would be exposed to DST/leap ambiguities.
struct VimshottariCalculator {
    static let nakshatraArc = 360.0 / 27.0
    static let yearDays = 365.25
    static let totalYears = 120.0

    private let lords = PanchangNames.vimshottariLords
    private let years = PanchangNames.vimshottariYears

    /// - Parameters:
    ///   - birthJulianDay: Julian Day (UT) of birth.
    ///   - moonLongitudeSidereal: the Moon's sidereal ecliptic longitude at birth, degrees.
    ///   - asOf: the instant against which `isCurrent` is evaluated.
    func compute(birthJulianDay: Double, moonLongitudeSidereal: Double, asOf: Date) -> VimshottariDasha {
        let moonLon = AngleMath.normalize360(moonLongitudeSidereal)
        let nakshatra = min(26, Int(moonLon / Self.nakshatraArc))
        let startIdx = nakshatra % 9
        let positionInNakshatra = moonLon - Double(nakshatra) * Self.nakshatraArc
        let fractionRemaining = 1.0 - positionInNakshatra / Self.nakshatraArc

        // The running lord at birth is `fractionRemaining` from finishing → it began
        // `years[startIdx]·(1−fractionRemaining)` ago.
        let elapsedYears = years[startIdx] * (1.0 - fractionRemaining)
        let firstStartJD = birthJulianDay - elapsedYears * Self.yearDays
        let asOfJD = JulianDate.julianDay(from: asOf)

        var mahadashas: [VimshottariDasha.Period] = []
        var jd = firstStartJD
        for i in 0..<9 {
            let idx = (startIdx + i) % 9
            let endJD = jd + years[idx] * Self.yearDays
            mahadashas.append(.init(
                id: "MD-\(lords[idx])",
                planet: lords[idx],
                start: JulianDate.date(from: jd),
                end: JulianDate.date(from: endJD),
                isCurrent: asOfJD >= jd && asOfJD < endJD
            ))
            jd = endJD
        }

        let currentAntardashas = antardashas(
            of: mahadashas.first(where: \.isCurrent),
            asOfJD: asOfJD
        )
        return VimshottariDasha(mahadashas: mahadashas, currentAntardashas: currentAntardashas)
    }

    /// The nine antardashas of a mahadasha: each lord's share is `mdYears·subYears/120`, in
    /// sequence starting from the mahadasha lord itself.
    private func antardashas(of mahadasha: VimshottariDasha.Period?, asOfJD: Double) -> [VimshottariDasha.Period] {
        guard let mahadasha, let mdIdx = lords.firstIndex(of: mahadasha.planet) else { return [] }
        let mdYears = years[mdIdx]
        var result: [VimshottariDasha.Period] = []
        var jd = JulianDate.julianDay(from: mahadasha.start)
        for i in 0..<9 {
            let subIdx = (mdIdx + i) % 9
            let endJD = jd + mdYears * years[subIdx] / Self.totalYears * Self.yearDays
            result.append(.init(
                id: "AD-\(mahadasha.planet)-\(lords[subIdx])",
                planet: lords[subIdx],
                start: JulianDate.date(from: jd),
                end: JulianDate.date(from: endJD),
                isCurrent: asOfJD >= jd && asOfJD < endJD
            ))
            jd = endJD
        }
        return result
    }
}
