import Foundation

// MARK: - Types

/// Choghadiya: 8 day segments (sunrise→sunset) + 8 night segments (sunset→next sunrise).
/// Each segment is named from a fixed cyclic order; the starting name of each half is keyed to
/// the weekday. Tables are sourced/validated against drikpanchang (see ChoghadiyaTables).
public struct Choghadiya: Sendable, Equatable {
    public enum Quality: Sendable, Equatable { case good, bad, neutral }   // green / red / yellow

    public struct Segment: Sendable, Equatable, Identifiable {
        public let id: Int
        public let name: String
        public let quality: Quality
        public let start: Double   // JD (UT)
        public let end: Double     // JD (UT)
    }

    public let day: [Segment]    // 8 segments, sunrise→sunset
    public let night: [Segment]  // 8 segments, sunset→next sunrise
}

/// A planetary hour: 1/12 of the day (sunrise→sunset) or night (sunset→next sunrise) span.
public struct Hora: Sendable, Equatable, Identifiable {
    public let id: Int          // 0…23 from sunrise
    public let planet: String
    public let start: Double    // JD (UT)
    public let end: Double      // JD (UT)
}

// MARK: - Computation

enum ChoghadiyaCalc {
    /// Day half: names advance +1 through this order, starting at `dayStart[weekday]`.
    /// This is the Chaldean planetary order (Saturn→…→Moon) mapped to Choghadiya names.
    static let dayCycle = ["Udvega", "Chara", "Labha", "Amrita", "Kala", "Shubha", "Roga"]
    /// Night half: names advance +1 through this (different) order, starting at `nightStart[weekday]`.
    static let nightCycle = ["Labha", "Udvega", "Shubha", "Amrita", "Chara", "Roga", "Kala"]

    /// Start index into `dayCycle` / `nightCycle`, weekday 0 = Sunday … 6 = Saturday.
    /// Sourced reference data: equals the classical Din/Raatri Choghadiya start tables and is
    /// validated against drikpanchang vectors for Sun/Tue/Sat (m1_muhurta_vectors.json).
    static let dayStart:   [Int] = [0, 3, 6, 2, 5, 1, 4]   // (3·wd) mod 7
    static let nightStart: [Int] = [2, 4, 6, 1, 3, 5, 0]   // (2 + 2·wd) mod 7

    /// Classical auspiciousness class (not carried by the validation vectors): Amrita/Shubha/
    /// Labha are good, Chara is neutral, Udvega/Kala/Roga are bad.
    static func quality(_ name: String) -> Choghadiya.Quality {
        switch name {
        case "Amrita", "Shubha", "Labha": return .good
        case "Chara":                     return .neutral
        default:                          return .bad   // Udvega, Kala, Roga
        }
    }

    /// - Parameters:
    ///   - weekday: 0 = Sunday … 6 = Saturday (vara at sunrise).
    /// Returns empty halves if any boundary is missing or non-monotonic (high-latitude days).
    static func compute(sunrise: Double?, sunset: Double?, nextSunrise: Double?, weekday: Int) -> Choghadiya {
        guard let sunrise, let sunset, let nextSunrise,
              sunset > sunrise, nextSunrise > sunset else {
            return Choghadiya(day: [], night: [])
        }
        let dayUnit = (sunset - sunrise) / 8.0
        let nightUnit = (nextSunrise - sunset) / 8.0

        func half(start: Double, unit: Double, cycle: [String], startIndex: Int) -> [Choghadiya.Segment] {
            (0..<8).map { i in
                let name = cycle[(startIndex + i) % 7]
                let s = start + Double(i) * unit
                return Choghadiya.Segment(id: i, name: name, quality: quality(name), start: s, end: s + unit)
            }
        }

        return Choghadiya(
            day: half(start: sunrise, unit: dayUnit, cycle: dayCycle, startIndex: dayStart[weekday]),
            night: half(start: sunset, unit: nightUnit, cycle: nightCycle, startIndex: nightStart[weekday])
        )
    }
}

enum DurMuhurtamCalc {
    /// Inauspicious day/night muhurta ordinals (1-based) per weekday, 0 = Sunday … 6 = Saturday.
    /// Day and night are each divided into 15 equal muhurtas. Sourced reference data (classical
    /// Dur Muhurtam table); validated against drikpanchang vectors for Sun/Tue/Sat.
    static let dayMuhurtas:   [[Int]] = [[14], [9, 12], [4], [8], [6], [4, 9], [1, 2]]
    static let nightMuhurtas: [[Int]] = [[],   [],       [7], [],  [12], [],     []]

    /// Returns the day's Dur Muhurtam windows (day windows first, then night), or [] if any
    /// boundary is missing/non-monotonic.
    static func compute(sunrise: Double?, sunset: Double?, nextSunrise: Double?, weekday: Int) -> [MuhurtaWindow] {
        guard let sunrise, let sunset, let nextSunrise,
              sunset > sunrise, nextSunrise > sunset else { return [] }
        let dayUnit = (sunset - sunrise) / 15.0
        let nightUnit = (nextSunrise - sunset) / 15.0
        let day = dayMuhurtas[weekday].map { k in
            MuhurtaWindow(start: sunrise + Double(k - 1) * dayUnit, end: sunrise + Double(k) * dayUnit)
        }
        let night = nightMuhurtas[weekday].map { k in
            MuhurtaWindow(start: sunset + Double(k - 1) * nightUnit, end: sunset + Double(k) * nightUnit)
        }
        return day + night
    }
}

enum HoraCalc {
    /// Chaldean order of planetary-hour lords. Each hora advances +1 here; the first hora at
    /// sunrise is the weekday's lord, so the 25th hora (next sunrise) is the next day's lord.
    static let chaldean = ["Saturn", "Jupiter", "Mars", "Sun", "Venus", "Mercury", "Moon"]
    /// Index in `chaldean` of each weekday's ruling planet, 0 = Sunday … 6 = Saturday.
    static let weekdayLord: [Int] = [3, 6, 2, 5, 1, 4, 0]   // Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn

    /// 24 planetary hours: 12 over the day (sunrise→sunset), 12 over the night (sunset→next
    /// sunrise). Returns [] if any boundary is missing/non-monotonic.
    static func compute(sunrise: Double?, sunset: Double?, nextSunrise: Double?, weekday: Int) -> [Hora] {
        guard let sunrise, let sunset, let nextSunrise,
              sunset > sunrise, nextSunrise > sunset else { return [] }
        let dayUnit = (sunset - sunrise) / 12.0
        let nightUnit = (nextSunrise - sunset) / 12.0
        let lord0 = weekdayLord[weekday]

        return (0..<24).map { i in
            let planet = chaldean[(lord0 + i) % 7]
            let start = i < 12 ? sunrise + Double(i) * dayUnit
                               : sunset + Double(i - 12) * nightUnit
            let unit = i < 12 ? dayUnit : nightUnit
            return Hora(id: i, planet: planet, start: start, end: start + unit)
        }
    }
}
