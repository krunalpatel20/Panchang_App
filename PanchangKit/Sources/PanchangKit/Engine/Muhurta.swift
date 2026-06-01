import Foundation

/// A named time window, as Julian Days (UT). `nil` bounds indicate the window is undefined
/// for the day (e.g. no sunrise at high latitude).
public struct MuhurtaWindow: Sendable, Equatable {
    public let start: Double?
    public let end: Double?
    public init(start: Double?, end: Double?) {
        self.start = start
        self.end = end
    }
}

public struct Muhurtas: Sendable, Equatable {
    public let rahuKalam: MuhurtaWindow
    public let yamaganda: MuhurtaWindow
    public let gulika: MuhurtaWindow
    public let abhijit: MuhurtaWindow
    public let brahmaMuhurta: MuhurtaWindow
}

/// Deterministic muhurta windows from sunrise/sunset + weekday (SPEC §5).
/// Daytime (sunrise→sunset) is split into 8 equal parts for Rahu Kalam / Yamaganda / Gulika
/// (the part index is fixed per weekday). Abhijit is the 8th of 15 equal day-muhurtas
/// (straddling solar noon). Brahma Muhurta is the 2-ghati window ending one night-muhurta
/// before sunrise. The per-weekday part indices below are verified against the SPEC's
/// Washington-D.C. worked example (Thursday).
enum Muhurta {
    // 1-based day-part (1…8 from sunrise) per weekday, index 0 = Sunday … 6 = Saturday.
    private static let rahuPart: [Int]      = [8, 2, 7, 5, 6, 4, 3]
    private static let yamagandaPart: [Int] = [5, 4, 3, 2, 1, 7, 6]
    private static let gulikaPart: [Int]    = [7, 6, 5, 4, 3, 2, 1]

    private static func eighth(part: Int, sunrise: Double, dayLength: Double) -> MuhurtaWindow {
        let unit = dayLength / 8.0
        let start = sunrise + Double(part - 1) * unit
        return MuhurtaWindow(start: start, end: start + unit)
    }

    /// - Parameters:
    ///   - weekday: 0 = Sunday … 6 = Saturday (vara at sunrise).
    ///   - previousSunset: sunset of the prior civil day, for the night length used by Brahma
    ///     Muhurta. If `nil`, night is approximated as 24h − daytime.
    static func windows(sunrise: Double?, sunset: Double?, previousSunset: Double?, weekday: Int) -> Muhurtas {
        guard let sunrise, let sunset, sunset > sunrise else {
            let empty = MuhurtaWindow(start: nil, end: nil)
            return Muhurtas(rahuKalam: empty, yamaganda: empty, gulika: empty, abhijit: empty, brahmaMuhurta: empty)
        }
        let dayLength = sunset - sunrise

        let rahu = eighth(part: rahuPart[weekday], sunrise: sunrise, dayLength: dayLength)
        let yama = eighth(part: yamagandaPart[weekday], sunrise: sunrise, dayLength: dayLength)
        let gul = eighth(part: gulikaPart[weekday], sunrise: sunrise, dayLength: dayLength)

        // Abhijit: 8th of 15 equal day-muhurtas, centered on solar noon.
        let dayMuhurta = dayLength / 15.0
        let abhijit = MuhurtaWindow(start: sunrise + 7 * dayMuhurta, end: sunrise + 8 * dayMuhurta)

        // Brahma Muhurta: from (sunrise − 2·N) to (sunrise − N), N = one night-muhurta.
        let nightLength: Double
        if let previousSunset, sunrise > previousSunset {
            nightLength = sunrise - previousSunset
        } else {
            nightLength = 1.0 - dayLength   // 24h − daytime, in days
        }
        let nightMuhurta = nightLength / 15.0
        let brahma = MuhurtaWindow(start: sunrise - 2 * nightMuhurta, end: sunrise - nightMuhurta)

        return Muhurtas(rahuKalam: rahu, yamaganda: yama, gulika: gul, abhijit: abhijit, brahmaMuhurta: brahma)
    }
}
