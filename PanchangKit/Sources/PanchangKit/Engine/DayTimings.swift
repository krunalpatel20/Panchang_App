import Foundation

/// Sun and Moon rise/set for a civil day at a location. Times are Julian Days (UT); the
/// presentation layer renders them in the location's timezone (with the panchang's
/// past-midnight ">24:00" / "+1" convention, SPEC §5).
public struct DayTimings: Sendable, Equatable {
    public let sunrise: Double?
    public let sunset: Double?
    public let moonrise: Double?
    public let moonset: Double?
    /// Set when the Sun never rises/sets (high latitude) — surfaced so the UI can explain it.
    public let sunNeverRises: Bool
    public let sunNeverSets: Bool

    public init(sunrise: Double?, sunset: Double?, moonrise: Double?, moonset: Double?,
                sunNeverRises: Bool, sunNeverSets: Bool) {
        self.sunrise = sunrise
        self.sunset = sunset
        self.moonrise = moonrise
        self.moonset = moonset
        self.sunNeverRises = sunNeverRises
        self.sunNeverSets = sunNeverSets
    }
}

struct DayTimingsCalculator {
    let ephemeris: Ephemeris

    private enum Event { case rise, set }

    /// SwiftAA reconstructs rise/set onto the *UT day* of the anchor, so an event whose true
    /// instant lies just across UT-midnight (e.g. a 20:25-local summer sunset in the western
    /// hemisphere) lands on the wrong UT day. We therefore gather candidates from the UT days
    /// around the target and select by where they actually fall in local time.
    private func candidates(body: Body, event: Event, noonJD: Double, location: GeoLocation) -> [Double] {
        var out: [Double] = []
        for offset in -1...2 {
            let rs = ephemeris.riseTransitSet(body: body, anchorJulianDay: noonJD + Double(offset), location: location)
            if let t = (event == .rise ? rs.rise : rs.set) { out.append(t) }
        }
        // Dedupe near-identical instants produced by adjacent anchors (< ~15 min apart).
        return out.sorted().reduce(into: [Double]()) { acc, t in
            if acc.last.map({ t - $0 > 0.01 }) ?? true { acc.append(t) }
        }
    }

    private func localDateMatches(_ jd: Double, year: Int, month: Int, day: Int, timeZone: TimeZone) -> Bool {
        let c = JulianDate.components(julianDay: jd, timeZone: timeZone)
        return c.year == year && c.month == month && c.day == day
    }

    func timings(year: Int, month: Int, day: Int, location: GeoLocation) -> DayTimings {
        let tz = location.timeZone
        guard let noon = JulianDate.julianDay(year: year, month: month, day: day, hour: 12, timeZone: tz) else {
            return DayTimings(sunrise: nil, sunset: nil, moonrise: nil, moonset: nil,
                              sunNeverRises: false, sunNeverSets: false)
        }

        // Sun rise/set for the target civil date.
        let sunRises = candidates(body: .sun, event: .rise, noonJD: noon, location: location)
        let sunSets = candidates(body: .sun, event: .set, noonJD: noon, location: location)
        let sunrise = sunRises.first { localDateMatches($0, year: year, month: month, day: day, timeZone: tz) }
        // Next sunrise bounds the panchang day (sunrise-to-sunrise); the Moon's rise/set are
        // attributed to that window, with the "+1" naturally falling on the next civil date.
        let nextSunrise = sunrise.flatMap { sr in sunRises.first { $0 > sr + 0.5 } }
        let windowEnd = nextSunrise ?? sunrise.map { $0 + 1.0 }

        let sunset: Double?
        if let sr = sunrise, let we = windowEnd {
            sunset = sunSets.first { $0 > sr && $0 < we }
        } else {
            sunset = sunSets.first { localDateMatches($0, year: year, month: month, day: day, timeZone: tz) }
        }

        // Moon rise/set within the panchang day window.
        var moonrise: Double?
        var moonset: Double?
        if let sr = sunrise, let we = windowEnd {
            moonrise = candidates(body: .moon, event: .rise, noonJD: noon, location: location).first { $0 >= sr && $0 < we }
            moonset = candidates(body: .moon, event: .set, noonJD: noon, location: location).first { $0 >= sr && $0 < we }
        }

        // High-latitude flags from the target UT day.
        let sunAnchor = ephemeris.riseTransitSet(body: .sun, anchorJulianDay: noon, location: location)
        return DayTimings(
            sunrise: sunrise,
            sunset: sunset,
            moonrise: moonrise,
            moonset: moonset,
            sunNeverRises: sunAnchor.alwaysDown,
            sunNeverSets: sunAnchor.alwaysUp
        )
    }

    /// Sunrise as a Julian Day, with a defined fallback at high latitudes where the Sun does
    /// not rise: use local 06:00, so the sunrise-to-sunrise day and the limbs still resolve
    /// (the no-sunrise condition is reported separately for the UI).
    func sunriseOrReference(year: Int, month: Int, day: Int, location: GeoLocation) -> Double {
        if let sr = timings(year: year, month: month, day: day, location: location).sunrise { return sr }
        return JulianDate.julianDay(year: year, month: month, day: day, hour: 6, timeZone: location.timeZone)
            ?? JulianDate.julianDay(from: Date())
    }
}
