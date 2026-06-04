import Foundation

public struct MasaInfo: Sendable, Equatable {
    /// Amanta lunar-month index, 0 = Chaitra … 11 = Phalguna.
    public let amantaIndex: Int
    /// Purnimanta lunar-month index (Krishna paksha shifts forward by one month, SPEC §8).
    public let purnimantaIndex: Int
    public let amantaName: String
    public let purnimantaName: String
    /// Intercalary leap month ("Adhika"/Purushottam Maas): no solar sankranti within it.
    public let isAdhika: Bool
    /// Rare "lost" month: two sankrantis within one lunar month. Detected so it doesn't crash.
    public let isKshaya: Bool
}

public struct YearInfo: Sendable, Equatable {
    /// Vikram Samvat under the Chaitradi (North Indian) anchor.
    public let vikramSamvatChaitradi: Int
    /// Vikram Samvat under the Kartikadi (Gujarati/Western) anchor.
    public let vikramSamvatKartikadi: Int
    /// Ritu (season) index, 0 = Vasant.
    public let rituIndex: Int
    public let rituName: String
    public let ayana: String   // "Uttarayana" or "Dakshinayana"
}

/// Lunar-calendar derivations: new-moon solving, masa naming + adhika/kshaya detection,
/// samvatsara, ritu and ayana. Reference: webresh/drik-panchanga (masa/adhika-masa).
struct LunarCalendar {
    let ephemeris: Ephemeris
    let ayanamsa: Ayanamsa

    /// Mean synodic elongation rate, degrees/day (Moon gains on Sun).
    private static let elongationRate = 360.0 / 29.530588

    // MARK: new-moon solving

    /// Signed Moon−Sun longitude difference in (-180, 180]; zero exactly at new moon and
    /// increasing through zero there, so a sign change brackets the instant.
    private func signedElongation(_ jd: Double) -> Double {
        AngleMath.normalize180(ephemeris.moonLongitude(julianDay: jd) - ephemeris.sunLongitude(julianDay: jd))
    }

    /// The new-moon instant nearest `guess` (within ±~half a synodic month).
    private func newMoonNear(_ guess: Double) -> Double {
        var lo = guess
        var hi = guess
        if signedElongation(guess) >= 0 {
            // New moon is at/before the guess: walk `lo` back until elongation goes negative.
            var steps = 0
            while signedElongation(lo) >= 0 && steps < 25 { lo -= 1; steps += 1 }
        } else {
            var steps = 0
            while signedElongation(hi) < 0 && steps < 25 { hi += 1; steps += 1 }
        }
        while hi - lo > 1.0 / 86400.0 {
            let mid = (lo + hi) / 2
            if signedElongation(mid) < 0 { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    /// New moon at or before `jd`.
    private func lastNewMoon(before jd: Double) -> Double {
        let elong = AngleMath.normalize360(ephemeris.moonLongitude(julianDay: jd) - ephemeris.sunLongitude(julianDay: jd))
        let guess = jd - elong / Self.elongationRate
        var nm = newMoonNear(guess)
        if nm > jd { nm = newMoonNear(guess - 2) }   // safety: never return a future new moon
        return nm
    }

    /// First new moon strictly after `jd`.
    private func nextNewMoon(after jd: Double) -> Double {
        let elong = AngleMath.normalize360(ephemeris.moonLongitude(julianDay: jd) - ephemeris.sunLongitude(julianDay: jd))
        let guess = jd + (360 - elong) / Self.elongationRate
        var nm = newMoonNear(guess)
        if nm < jd { nm = newMoonNear(guess + 2) }
        return nm
    }

    // MARK: rashi / month naming

    /// Sidereal solar rashi number 1…12 (1 = Mesha) at the given instant.
    private func solarRashi(_ jd: Double) -> Int {
        let sidereal = AngleMath.normalize360(ephemeris.sunLongitude(julianDay: jd) - ayanamsa.value(julianDay: jd))
        return Int(floor(sidereal / 30.0)) + 1
    }

    /// Amanta month index (0 = Chaitra) for the lunar month beginning at new moon `nm`.
    /// drik-panchanga rule: month number = (solar rashi at the starting new moon) + 1.
    private func amantaIndex(forMonthStartingAt nm: Double) -> Int {
        var m = solarRashi(nm) + 1
        if m > 12 { m -= 12 }
        return m - 1
    }

    // MARK: public derivations

    func masa(atSunrise jd: Double, paksha: Paksha) -> MasaInfo {
        let last = lastNewMoon(before: jd)
        let next = nextNewMoon(after: jd)
        let startRashi = solarRashi(last)
        let endRashi = solarRashi(next)
        let isAdhika = (startRashi == endRashi)
        // Kshaya: the month skips a rashi (two sankrantis inside one lunar month).
        let span = (endRashi - startRashi + 12) % 12
        let isKshaya = span >= 2

        let amanta = amantaIndex(forMonthStartingAt: last)
        let purnimanta = paksha == .krishna ? (amanta + 1) % 12 : amanta
        return MasaInfo(
            amantaIndex: amanta,
            purnimantaIndex: purnimanta,
            amantaName: PanchangNames.masa[amanta],
            purnimantaName: PanchangNames.masa[purnimanta],
            isAdhika: isAdhika,
            isKshaya: isKshaya
        )
    }

    /// Gregorian year of the start of the most recent lunar month named `targetIndex`,
    /// walking back month-by-month from the current month. Used for samvatsara anchoring.
    private func gregorianYearOfMonthStart(targetIndex: Int, currentNewMoon: Double, currentIndex: Int, timeZone: TimeZone) -> Int {
        var nm = currentNewMoon
        var idx = currentIndex
        var steps = 0
        while idx != targetIndex && steps < 14 {
            nm = lastNewMoon(before: nm - 1)   // previous month's starting new moon
            idx = amantaIndex(forMonthStartingAt: nm)
            steps += 1
        }
        return JulianDate.components(julianDay: nm, timeZone: timeZone).year ?? 0
    }

    func year(atSunrise jd: Double, timeZone: TimeZone) -> YearInfo {
        let last = lastNewMoon(before: jd)
        let amanta = amantaIndex(forMonthStartingAt: last)

        // Vikram Samvat = (Gregorian year of the anchor month's most recent start) + 57.
        let chaitraYear = gregorianYearOfMonthStart(targetIndex: 0, currentNewMoon: last, currentIndex: amanta, timeZone: timeZone)
        let kartikaYear = gregorianYearOfMonthStart(targetIndex: 7, currentNewMoon: last, currentIndex: amanta, timeZone: timeZone)

        // Ritu (season) and ayana follow drikpanchang, which uses the TROPICAL (sayana) Sun:
        // ritu buckets are 60°-wide starting at Vasant (330°–30°), and Uttarayana runs from the
        // tropical winter solstice (270°) to the summer solstice (90°). This is the sayana
        // convention the authority displays — not the nirayana/lunar-month basis.
        let tropicalSun = ephemeris.sunLongitude(julianDay: jd)
        let rituIndex = Int(AngleMath.normalize360(tropicalSun + 30) / 60)
        let ayana = (tropicalSun >= 270 || tropicalSun < 90) ? "Uttarayana" : "Dakshinayana"

        return YearInfo(
            vikramSamvatChaitradi: chaitraYear + 57,
            vikramSamvatKartikadi: kartikaYear + 57,
            rituIndex: rituIndex,
            rituName: PanchangNames.ritu[rituIndex],
            ayana: ayana
        )
    }
}
