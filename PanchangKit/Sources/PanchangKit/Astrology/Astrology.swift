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
        let calc = PlanetaryCalculator(ephemeris: ephemeris, ayanamsa: ayanamsa)
        return calc.positions(julianDay: jd, lagnaLongitude: siderealAscendant(julianDay: jd, location: location))
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

    /// Sidereal ascendant longitude, degrees [0, 360).
    func siderealAscendant(julianDay jd: Double, location: GeoLocation) -> Double {
        // Local apparent sidereal time = Greenwich AST + east longitude.
        let lst = AngleMath.normalize360(
            ephemeris.greenwichApparentSiderealTime(julianDay: jd) + location.longitude
        )
        let tropical = Lagna.tropicalAscendant(
            localSiderealTimeDeg: lst,
            latitude: location.latitude,
            obliquity: ephemeris.obliquityOfEcliptic(julianDay: jd)
        )
        return AngleMath.normalize360(tropical - ayanamsa.value(julianDay: jd))
    }
}
