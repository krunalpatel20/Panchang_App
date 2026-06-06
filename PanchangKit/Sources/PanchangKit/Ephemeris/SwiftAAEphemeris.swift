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

    public func longitude(of graha: Graha, julianDay: Double) -> Double {
        let jd = JulianDay(julianDay)
        switch graha {
        case .sun:  return sunLongitude(julianDay: julianDay)
        case .moon: return moonLongitude(julianDay: julianDay)
        // SwiftAA's planets expose apparent geocentric *equatorial* coordinates; convert to
        // ecliptic for the longitude. (Sun/Moon have a direct apparentEclipticCoordinates;
        // the planets do not, so the makeEclipticCoordinates() hop is required and is the
        // easy thing to get wrong — using heliocentricEclipticCoordinates would be wrong.)
        case .mars:    return ecliptic(Mars(julianDay: jd))
        case .mercury: return ecliptic(Mercury(julianDay: jd))
        case .jupiter: return ecliptic(Jupiter(julianDay: jd))
        case .venus:   return ecliptic(Venus(julianDay: jd))
        case .saturn:  return ecliptic(Saturn(julianDay: jd))
        }
    }

    private func ecliptic(_ planet: Planet) -> Double {
        AngleMath.normalize360(planet.equatorialCoordinates.makeEclipticCoordinates().celestialLongitude.value)
    }

    public func lunarNodeLongitude(julianDay: Double) -> Double {
        AngleMath.normalize360(Moon(julianDay: JulianDay(julianDay)).longitudeOfMeanAscendingNode.value)
    }

    public func greenwichApparentSiderealTime(julianDay: Double) -> Double {
        AngleMath.normalize360(JulianDay(julianDay).apparentGreenwichSiderealTime().inDegrees.value)
    }

    public func obliquityOfEcliptic(julianDay: Double) -> Double {
        Earth(julianDay: JulianDay(julianDay)).obliquityOfEcliptic(mean: false).value
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
