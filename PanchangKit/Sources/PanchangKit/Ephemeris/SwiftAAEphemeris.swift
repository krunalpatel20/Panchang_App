import Foundation
import SwiftAA

/// `Ephemeris` backed by SwiftAA (Meeus / AA+). Apparent positions include nutation and
/// aberration; using apparent longitudes consistently for both bodies means the small
/// nutation term cancels in the Moon−Sun elongation (tithi/karana) and stays within the
/// engine's ~1–2 min tolerance for the sidereal limbs.
public struct SwiftAAEphemeris: Ephemeris {
    public init() {}

    public func sunLongitude(julianDay: Double) -> Double {
        let jd = JulianDay(julianDay)
        let lon = Sun(julianDay: jd).apparentEclipticCoordinates.celestialLongitude.value
        return AngleMath.normalize360(lon)
    }

    public func moonLongitude(julianDay: Double) -> Double {
        let jd = JulianDay(julianDay)
        let lon = Moon(julianDay: jd).apparentEclipticCoordinates.celestialLongitude.value
        return AngleMath.normalize360(lon)
    }

    public func riseTransitSet(body: Body, anchorJulianDay: Double, location: GeoLocation) -> RiseSet {
        // SwiftAA's GeographicCoordinates uses positively-WESTWARD longitude (Meeus),
        // so a standard east-positive longitude is negated here.
        let geo = GeographicCoordinates(
            positivelyWestwardLongitude: Degree(-location.longitude),
            latitude: Degree(location.latitude)
        )
        let anchor = JulianDay(anchorJulianDay)
        let times: RiseTransitSetTimes
        switch body {
        case .sun:
            times = RiseTransitSetTimes(celestialBody: Sun(julianDay: anchor), geographicCoordinates: geo)
        case .moon:
            times = RiseTransitSetTimes(celestialBody: Moon(julianDay: anchor), geographicCoordinates: geo)
        }

        let alwaysUp = times.transitError == .alwaysAboveAltitude
        let alwaysDown = times.transitError == .alwaysBelowAltitude
        return RiseSet(
            rise: times.riseTime?.value,
            transit: times.transitTime?.value,
            set: times.setTime?.value,
            alwaysUp: alwaysUp,
            alwaysDown: alwaysDown
        )
    }
}
