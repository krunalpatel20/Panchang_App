import Foundation

/// Top-level engine facade: assembles a `PanchangDay` for a civil date + location + preset.
/// Services (ephemeris, ayanamsa) are injected so the engine is testable with synthetic data
/// and so alternative ayanamsa modes can be supplied in v2 (SPEC §3.4).
public struct Panchang: Sendable {
    private let ephemeris: Ephemeris
    private let ayanamsa: Ayanamsa

    public init(ephemeris: Ephemeris = SwiftAAEphemeris(), ayanamsa: Ayanamsa = LahiriAyanamsa()) {
        self.ephemeris = ephemeris
        self.ayanamsa = ayanamsa
    }

    /// Compute the panchang for a civil date (interpreted in `location.timeZone`).
    public func compute(year: Int, month: Int, day: Int, location: GeoLocation, config: CalendarConfig) -> PanchangDay {
        let timingsCalc = DayTimingsCalculator(ephemeris: ephemeris)
        let timings = timingsCalc.timings(year: year, month: month, day: day, location: location)

        // The Hindu day runs sunrise-to-sunrise; every limb is reported as prevailing at
        // sunrise. Fall back to a defined reference if the Sun does not rise (high latitude).
        let sunrise = timings.sunrise
            ?? timingsCalc.sunriseOrReference(year: year, month: month, day: day, location: location)

        let limbs = FiveLimbs(ephemeris: ephemeris, ayanamsa: ayanamsa)
        let tithi = limbs.tithi(atSunrise: sunrise)
        let karana = limbs.karana(atSunrise: sunrise)
        let nakshatra = limbs.nakshatra(atSunrise: sunrise)
        let yoga = limbs.yoga(atSunrise: sunrise)
        let vara = limbs.vara(sunriseJulianDay: sunrise, timeZone: location.timeZone)

        let lunar = LunarCalendar(ephemeris: ephemeris, ayanamsa: ayanamsa)
        let masa = lunar.masa(atSunrise: sunrise, paksha: tithi.paksha)
        let yearInfo = lunar.year(atSunrise: sunrise, timeZone: location.timeZone)

        // Previous civil day's sunset, for the night length Brahma Muhurta needs.
        let previousSunset = previousDaySunset(year: year, month: month, day: day, location: location, calc: timingsCalc)
        let muhurtas = Muhurta.windows(
            sunrise: timings.sunrise,
            sunset: timings.sunset,
            previousSunset: previousSunset,
            weekday: vara.index
        )

        return PanchangDay(
            year: year, month: month, day: day,
            location: location, config: config,
            tithi: tithi, vara: vara, nakshatra: nakshatra, yoga: yoga, karana: karana,
            masa: masa, yearInfo: yearInfo,
            timings: timings, muhurtas: muhurtas,
            sunNeverRises: timings.sunNeverRises, sunNeverSets: timings.sunNeverSets
        )
    }

    private func previousDaySunset(year: Int, month: Int, day: Int, location: GeoLocation, calc: DayTimingsCalculator) -> Double? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        guard let date = cal.date(from: comps),
              let prev = cal.date(byAdding: .day, value: -1, to: date) else { return nil }
        let p = cal.dateComponents([.year, .month, .day], from: prev)
        return calc.timings(year: p.year!, month: p.month!, day: p.day!, location: location).sunset
    }
}
