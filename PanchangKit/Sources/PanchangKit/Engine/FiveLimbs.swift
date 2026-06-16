import Foundation

public enum Paksha: String, Sendable, Equatable, Codable {
    case shukla = "Shukla"
    case krishna = "Krishna"
}

public struct TithiInfo: Sendable, Equatable {
    public let index: Int          // 0…29 (0 = Shukla Pratipada, 29 = Amavasya)
    public let name: String
    public let paksha: Paksha
    public let endJulianDay: Double
}

public struct NakshatraInfo: Sendable, Equatable {
    public let index: Int          // 0…26
    public let name: String
    public let endJulianDay: Double
}

public struct YogaInfo: Sendable, Equatable {
    public let index: Int          // 0…26
    public let name: String
    public let endJulianDay: Double
}

public struct KaranaInfo: Sendable, Equatable {
    public let index: Int          // 0…59 half-tithi position in the lunar month
    public let name: String
    public let endJulianDay: Double
}

public struct VaraInfo: Sendable, Equatable {
    public let index: Int          // 0 = Sunday
    public let name: String
}

/// Computes the five limbs and their end times from Sun/Moon longitudes.
///
/// SPEC §5: tithi and karana derive from the Moon−Sun elongation and are **ayanamsa-
/// independent** (the ayanamsa cancels in the difference). Nakshatra uses the sidereal Moon
/// and yoga the sum of sidereal Sun + Moon, so both **require** the ayanamsa.
struct FiveLimbs {
    let ephemeris: Ephemeris
    let ayanamsa: Ayanamsa

    static let nakshatraArc = 360.0 / 27.0   // 13°20′
    static let tithiArc = 12.0
    static let karanaArc = 6.0

    // MARK: angle sources (all monotonically increasing with time)

    /// Moon−Sun elongation, degrees [0, 360). Basis for tithi and karana.
    private func elongation(_ jd: Double) -> Double {
        AngleMath.normalize360(ephemeris.moonLongitude(julianDay: jd) - ephemeris.sunLongitude(julianDay: jd))
    }

    /// Sidereal Moon longitude, degrees [0, 360). Basis for nakshatra.
    private func siderealMoon(_ jd: Double) -> Double {
        AngleMath.normalize360(ephemeris.moonLongitude(julianDay: jd) - ayanamsa.value(julianDay: jd))
    }

    /// Sidereal Sun + sidereal Moon, degrees [0, 360). Basis for yoga (ayanamsa applied twice).
    private func yogaSum(_ jd: Double) -> Double {
        let sun = ephemeris.sunLongitude(julianDay: jd)
        let moon = ephemeris.moonLongitude(julianDay: jd)
        let ay = ayanamsa.value(julianDay: jd)
        return AngleMath.normalize360(sun + moon - 2 * ay)
    }

    /// Julian Day at which `angleAt` (monotone increasing, wraps at 360) reaches the upper
    /// edge of the segment currently containing `valueAtStart`.
    private func endOfSegment(arc: Double, valueAtStart: Double, startJD: Double, angleAt: @escaping (Double) -> Double) -> Double {
        let segmentIndex = floor(valueAtStart / arc)
        let target = (segmentIndex + 1) * arc
        let unwrapped: (Double) -> Double = { jd in
            let raw = angleAt(jd)
            return raw < valueAtStart ? raw + 360 : raw
        }
        let crossing = AngleMath.solveCrossing(
            targetValue: target,
            startJD: startJD,
            step: 0.02,
            maxSpan: 2.0,
            angleAt: unwrapped
        )
        // Fallback: a segment is always crossed within ~1.3 days, so a nil here would be a
        // bug; return startJD + 2 so the failure is visible rather than crashing.
        return crossing ?? (startJD + 2.0)
    }

    // MARK: limbs

    func tithi(atSunrise jd: Double) -> TithiInfo {
        let elong = elongation(jd)
        let index = min(29, Int(floor(elong / Self.tithiArc)))
        let end = endOfSegment(arc: Self.tithiArc, valueAtStart: elong, startJD: jd, angleAt: { self.elongation($0) })
        return TithiInfo(
            index: index,
            name: PanchangNames.tithi[index],
            paksha: index < 15 ? .shukla : .krishna,
            endJulianDay: end
        )
    }

    func karana(atSunrise jd: Double) -> KaranaInfo {
        let elong = elongation(jd)
        let index = min(59, Int(floor(elong / Self.karanaArc)))
        let end = endOfSegment(arc: Self.karanaArc, valueAtStart: elong, startJD: jd, angleAt: { self.elongation($0) })
        return KaranaInfo(index: index, name: PanchangNames.karana(halfTithiIndex: index), endJulianDay: end)
    }

    func nakshatra(atSunrise jd: Double) -> NakshatraInfo {
        let value = siderealMoon(jd)
        let index = min(26, Int(floor(value / Self.nakshatraArc)))
        let end = endOfSegment(arc: Self.nakshatraArc, valueAtStart: value, startJD: jd, angleAt: { self.siderealMoon($0) })
        return NakshatraInfo(index: index, name: PanchangNames.nakshatra[index], endJulianDay: end)
    }

    /// The nakshatra segment (index, start JD, end JD) containing `jd`. Varjyam/Amrit Kalam are
    /// fractions of this span measured from its start, so they need the start time too.
    func nakshatraSegment(containing jd: Double) -> (index: Int, start: Double, end: Double) {
        let value = siderealMoon(jd)
        let index = min(26, Int(floor(value / Self.nakshatraArc)))
        let end = endOfSegment(arc: Self.nakshatraArc, valueAtStart: value, startJD: jd, angleAt: { self.siderealMoon($0) })
        let start = startOfSegment(target: Double(index) * Self.nakshatraArc, near: jd, angleAt: { self.siderealMoon($0) })
        return (index, start, end)
    }

    /// JD at which a monotone-increasing angle last crossed `target`, searching back from `near`.
    /// Uses a modular signed distance so it is correct across the 360°→0° wrap.
    private func startOfSegment(target: Double, near: Double, angleAt: @escaping (Double) -> Double) -> Double {
        func signedDistance(_ jd: Double) -> Double {
            ((angleAt(jd) - target + 540).truncatingRemainder(dividingBy: 360)) - 180   // (-180, 180]
        }
        var lo = near - 1.5, hi = near   // 1.5 days back > one 13°20′ segment of Moon motion
        for _ in 0..<60 {
            let mid = (lo + hi) / 2
            if signedDistance(mid) < 0 { lo = mid } else { hi = mid }
        }
        return (lo + hi) / 2
    }

    /// The Moon's sidereal rashi (zodiac sign) index 0…11 at the given instant — for Chandra Bala.
    func moonRashi(atSunrise jd: Double) -> Int {
        min(11, Int(floor(siderealMoon(jd) / 30.0)))
    }

    /// The Sun's sidereal rashi index 0…11 — basis for Sankranti detection.
    func sunRashi(atSunrise jd: Double) -> Int {
        let sidereal = AngleMath.normalize360(ephemeris.sunLongitude(julianDay: jd) - ayanamsa.value(julianDay: jd))
        return min(11, Int(floor(sidereal / 30.0)))
    }

    func yoga(atSunrise jd: Double) -> YogaInfo {
        let value = yogaSum(jd)
        let index = min(26, Int(floor(value / Self.nakshatraArc)))
        let end = endOfSegment(arc: Self.nakshatraArc, valueAtStart: value, startJD: jd, angleAt: { self.yogaSum($0) })
        return YogaInfo(index: index, name: PanchangNames.yoga[index], endJulianDay: end)
    }

    /// Vara is the civil weekday prevailing at sunrise (the Hindu day starts at sunrise).
    func vara(sunriseJulianDay jd: Double, timeZone: TimeZone) -> VaraInfo {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        // Foundation weekday: 1 = Sunday … 7 = Saturday → 0…6 (matches PanchangNames.vara).
        let weekday = cal.component(.weekday, from: JulianDate.date(from: jd)) - 1
        return VaraInfo(index: weekday, name: PanchangNames.vara[weekday])
    }
}
