import Foundation

/// A celestial body the engine needs rise/set information for.
public enum Body: Sendable {
    case sun
    case moon
}

/// The seven visible grahas whose ecliptic longitude the astrology layer (M2) needs.
/// Rahu/Ketu are not here — they come from the lunar node, not a body position.
public enum Graha: String, Sendable, CaseIterable {
    case sun, moon, mars, mercury, jupiter, venus, saturn
}

/// Rise / transit / set instants for a body on a given day, in Julian Day (UT).
/// Any of the three may be `nil` at high latitudes when the body does not cross the horizon.
public struct RiseSet: Sendable, Equatable {
    public let rise: Double?
    public let transit: Double?
    public let set: Double?
    /// True when the body never set on this day (circumpolar above horizon).
    public let alwaysUp: Bool
    /// True when the body never rose on this day (below horizon all day).
    public let alwaysDown: Bool

    public init(rise: Double?, transit: Double?, set: Double?, alwaysUp: Bool = false, alwaysDown: Bool = false) {
        self.rise = rise
        self.transit = transit
        self.set = set
        self.alwaysUp = alwaysUp
        self.alwaysDown = alwaysDown
    }
}

/// Abstraction over the astronomical backend so the engine is testable with synthetic
/// positions and independent of SwiftAA. All longitudes are **tropical** (sayana) apparent
/// geocentric ecliptic longitude in degrees [0, 360); the sidereal correction (ayanamsa)
/// is applied by the engine, never here.
public protocol Ephemeris: Sendable {
    /// Apparent geocentric tropical ecliptic longitude of the Sun, degrees [0, 360).
    func sunLongitude(julianDay: Double) -> Double
    /// Apparent geocentric tropical ecliptic longitude of the Moon, degrees [0, 360).
    func moonLongitude(julianDay: Double) -> Double
    /// Rise/transit/set for `body` on the UT day containing `anchorJulianDay`, at `location`.
    func riseTransitSet(body: Body, anchorJulianDay: Double, location: GeoLocation) -> RiseSet

    // MARK: - M2 astrology layer (all tropical; the engine applies ayanamsa)

    /// Apparent geocentric tropical ecliptic longitude of a graha, degrees [0, 360).
    func longitude(of graha: Graha, julianDay: Double) -> Double
    /// Tropical longitude of the Moon's **mean** ascending node (Rahu), degrees [0, 360).
    /// Ketu is the descending node: `normalize360(rahu + 180)`.
    func lunarNodeLongitude(julianDay: Double) -> Double
    /// Apparent Greenwich sidereal time expressed in **degrees** [0, 360).
    /// (Lagna input: local sidereal time = this + east longitude.)
    func greenwichApparentSiderealTime(julianDay: Double) -> Double
    /// True obliquity of the ecliptic (mean + nutation in obliquity), degrees.
    /// (Lagna input.)
    func obliquityOfEcliptic(julianDay: Double) -> Double
}
