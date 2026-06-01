import Foundation

/// The sidereal correction: `sidereal = tropical − ayanamsa(jd)`.
/// Injectable so alternative modes (Raman, KP, True Chitra) can be added in v2 and so the
/// engine's ayanamsa-independence invariant can be tested by swapping in a different value.
public protocol Ayanamsa: Sendable {
    /// Ayanamsa in degrees at the given Julian Day.
    func value(julianDay: Double) -> Double
}

/// Lahiri (Chitrapaksha) ayanamsa — the official Indian Calendar Reform Committee mode and
/// the default of the validation authority (drikpanchang.com).
///
/// Model: anchor at the Swiss Ephemeris Lahiri reference epoch and accumulate the IAU 2006
/// general precession in longitude (Capitaine et al. 2003).
///   - t0 = JD 2435553.5 (1956-01-01), ayanamsa(t0) = 23°15'00.66" = 23.250182777778°.
///   - p_A(T) = 5028.796195″·T + 1.1054348″·T²   (T = Julian centuries from J2000 TT)
///   - ayanamsa(JD) = ayanamsa(t0) + [p_A(T) − p_A(T0)] / 3600
///
/// This reproduces published Lahiri values to within ~0.01° across 1900–2100, which keeps
/// the sidereal limbs (nakshatra, yoga) inside the engine's ~1–2 min end-time tolerance.
/// `tithi`/`karana` do not use ayanamsa at all and are therefore exact w.r.t. this choice.
public struct LahiriAyanamsa: Ayanamsa {
    private static let t0: Double = 2435553.5
    private static let ayanamsaAtT0: Double = 23.250182777778
    private static let j2000: Double = 2451545.0

    public init() {}

    /// Accumulated IAU 2006 general precession in longitude (arcseconds) since J2000.
    private static func precessionArcsec(julianDay: Double) -> Double {
        let T = (julianDay - j2000) / 36525.0
        return 5028.796195 * T + 1.1054348 * T * T
    }

    public func value(julianDay: Double) -> Double {
        let delta = Self.precessionArcsec(julianDay: julianDay) - Self.precessionArcsec(julianDay: Self.t0)
        return Self.ayanamsaAtT0 + delta / 3600.0
    }
}
