import Foundation

/// Lagna (ascendant) — the ecliptic point rising on the eastern horizon. Pure trigonometry
/// over astronomical inputs (local sidereal time, latitude, obliquity) so it is unit-testable
/// without an ephemeris backend.
enum Lagna {
    /// Tropical ecliptic longitude of the ascendant, degrees [0, 360).
    ///
    /// - Parameters:
    ///   - localSiderealTimeDeg: local apparent sidereal time in degrees (the RAMC).
    ///   - latitude: geographic latitude, degrees (north positive).
    ///   - obliquity: true obliquity of the ecliptic, degrees.
    ///
    /// Oblique-ascension formula (Meeus, *Astronomical Algorithms*). The sign convention is
    /// the subtle part: `atan2(cos θ, −(sin θ·cos ε + tan φ·sin ε))` gives the **ascendant**;
    /// the mirror `atan2(−cos θ, …)` gives the **descendant**, exactly 180° away. Validated
    /// against Swiss Ephemeris `swe.houses_ex()` to < 0.01° including 59°N and 33°S.
    static func tropicalAscendant(localSiderealTimeDeg θdeg: Double, latitude φdeg: Double, obliquity εdeg: Double) -> Double {
        let θ = θdeg * .pi / 180
        let φ = φdeg * .pi / 180
        let ε = εdeg * .pi / 180
        let asc = atan2(cos(θ), -(sin(θ) * cos(ε) + tan(φ) * sin(ε)))
        return AngleMath.normalize360(asc * 180 / .pi)
    }
}
