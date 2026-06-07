import Foundation

/// Top-level astrology facade: sidereal planetary positions and the ascendant for an instant
/// + location. Services are injected like `Panchang`, so the layer is testable with synthetic
/// positions and supports alternative ayanamsa modes (M3).
public struct Astrology: Sendable {
    private let ephemeris: Ephemeris
    private let ayanamsa: Ayanamsa

    public init(ephemeris: Ephemeris = SwiftAAEphemeris(), ayanamsa: Ayanamsa = LahiriAyanamsa()) {
        self.ephemeris = ephemeris
        self.ayanamsa = ayanamsa
    }

    /// Sidereal positions of the nine grahas + the ascendant at `julianDay`, seen from `location`.
    public func positions(julianDay jd: Double, location: GeoLocation) -> PlanetaryPositions {
        // Share one cache across the planet loop, the retrograde re-sampling, and the ascendant —
        // e.g. each planet's longitude is read once for its position and again for its retrograde
        // check at the same instant, now a single evaluation.
        let eph = MemoizingEphemeris(base: ephemeris)
        let calc = PlanetaryCalculator(ephemeris: eph, ayanamsa: ayanamsa)
        return calc.positions(julianDay: jd, lagnaLongitude: siderealAscendant(eph: eph, julianDay: jd, location: location))
    }

    /// Vimshottari dasha for a birth instant. `asOf` selects which periods are marked current.
    public func dasha(birth: Date, asOf: Date = Date()) -> VimshottariDasha {
        let birthJD = JulianDate.julianDay(from: birth)
        let moonSidereal = AngleMath.normalize360(
            ephemeris.moonLongitude(julianDay: birthJD) - ayanamsa.value(julianDay: birthJD)
        )
        return VimshottariCalculator().compute(
            birthJulianDay: birthJD, moonLongitudeSidereal: moonSidereal, asOf: asOf
        )
    }

    /// The Moon's sidereal ecliptic longitude at `julianDay`, degrees [0, 360). A single ephemeris
    /// read — used to derive janma nakshatra/rashi without computing a full chart.
    public func moonSidereal(julianDay jd: Double) -> Double {
        AngleMath.normalize360(ephemeris.moonLongitude(julianDay: jd) - ayanamsa.value(julianDay: jd))
    }

    /// Sidereal ascendant longitude, degrees [0, 360). `eph` defaults to the injected backend; the
    /// public `positions` passes its per-call memoizer so the sidereal-time/obliquity reads share it.
    func siderealAscendant(eph: Ephemeris? = nil, julianDay jd: Double, location: GeoLocation) -> Double {
        let source = eph ?? ephemeris
        // Local apparent sidereal time = Greenwich AST + east longitude.
        let lst = AngleMath.normalize360(
            source.greenwichApparentSiderealTime(julianDay: jd) + location.longitude
        )
        let tropical = Lagna.tropicalAscendant(
            localSiderealTimeDeg: lst,
            latitude: location.latitude,
            obliquity: source.obliquityOfEcliptic(julianDay: jd)
        )
        return AngleMath.normalize360(tropical - ayanamsa.value(julianDay: jd))
    }
}
