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
        // One memoizing cache shared by every sub-engine for this day, so the heavily-repeated
        // Sun/Moon/rise-set evaluations (same anchors, overlapping solver grids, the masa/year and
        // samvatsara new-moon solves) collapse to dictionary hits. Results are unchanged.
        let eph = MemoizingEphemeris(base: ephemeris)
        let timingsCalc = DayTimingsCalculator(ephemeris: eph)
        let timings = timingsCalc.timings(year: year, month: month, day: day, location: location)

        // The Hindu day runs sunrise-to-sunrise; every limb is reported as prevailing at
        // sunrise. Fall back to a defined reference if the Sun does not rise (high latitude).
        let sunrise = timings.sunrise
            ?? timingsCalc.sunriseOrReference(year: year, month: month, day: day, location: location)

        let limbs = FiveLimbs(ephemeris: eph, ayanamsa: ayanamsa)
        let tithi = limbs.tithi(atSunrise: sunrise)
        let karana = limbs.karana(atSunrise: sunrise)
        let nakshatra = limbs.nakshatra(atSunrise: sunrise)
        let moonRashiIndex = limbs.moonRashi(atSunrise: sunrise)
        let sunRashiIndex  = limbs.sunRashi(atSunrise: sunrise)
        let previousSunRashiIndex = previousDaySunRashi(
            year: year, month: month, day: day, location: location, calc: timingsCalc, limbs: limbs
        )
        let isSolarTransition = previousSunRashiIndex != sunRashiIndex
        let yoga = limbs.yoga(atSunrise: sunrise)
        let vara = limbs.vara(sunriseJulianDay: sunrise, timeZone: location.timeZone)

        let lunar = LunarCalendar(ephemeris: eph, ayanamsa: ayanamsa)
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

        // Next civil day's sunrise bounds the Choghadiya/Hora night halves.
        let nextSunrise = nextDaySunrise(year: year, month: month, day: day, location: location, calc: timingsCalc)
        let choghadiya = ChoghadiyaCalc.compute(
            sunrise: timings.sunrise, sunset: timings.sunset, nextSunrise: nextSunrise, weekday: vara.index
        )
        let horas = HoraCalc.compute(
            sunrise: timings.sunrise, sunset: timings.sunset, nextSunrise: nextSunrise, weekday: vara.index
        )
        let durMuhurtam = DurMuhurtamCalc.compute(
            sunrise: timings.sunrise, sunset: timings.sunset, nextSunrise: nextSunrise, weekday: vara.index
        )
        let varjyamAmrit = VarjyamCalc.compute(sunrise: timings.sunrise, nextSunrise: nextSunrise, limbs: limbs)

        return PanchangDay(
            year: year, month: month, day: day,
            location: location, config: config,
            tithi: tithi, vara: vara, nakshatra: nakshatra, yoga: yoga, karana: karana,
            masa: masa, yearInfo: yearInfo,
            timings: timings, muhurtas: muhurtas,
            choghadiya: choghadiya, horas: horas, durMuhurtam: durMuhurtam,
            varjyam: varjyamAmrit.varjyam, amritKalam: varjyamAmrit.amrit,
            moonRashiIndex: moonRashiIndex,
            sunRashiIndex: sunRashiIndex,
            isSolarTransition: isSolarTransition,
            sunNeverRises: timings.sunNeverRises, sunNeverSets: timings.sunNeverSets
        )
    }

    private func previousDaySunRashi(
        year: Int, month: Int, day: Int, location: GeoLocation,
        calc: DayTimingsCalculator, limbs: FiveLimbs
    ) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        guard let date = cal.date(from: comps),
              let prev = cal.date(byAdding: .day, value: -1, to: date) else { return -1 }
        let p = cal.dateComponents([.year, .month, .day], from: prev)
        let prevTimings = calc.timings(year: p.year!, month: p.month!, day: p.day!, location: location)
        let prevSunrise = prevTimings.sunrise
            ?? calc.sunriseOrReference(year: p.year!, month: p.month!, day: p.day!, location: location)
        return limbs.sunRashi(atSunrise: prevSunrise)
    }

    private func nextDaySunrise(year: Int, month: Int, day: Int, location: GeoLocation, calc: DayTimingsCalculator) -> Double? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        guard let date = cal.date(from: comps),
              let next = cal.date(byAdding: .day, value: 1, to: date) else { return nil }
        let n = cal.dateComponents([.year, .month, .day], from: next)
        return calc.timings(year: n.year!, month: n.month!, day: n.day!, location: location).sunrise
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
