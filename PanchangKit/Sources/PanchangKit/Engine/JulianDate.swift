import Foundation

/// Pure Julian Day ↔ calendar conversions for the engine. Treats Julian Day as UT-based
/// (JD at Unix epoch 1970-01-01T00:00:00Z = 2440587.5); leap seconds are ignored, which is
/// well within the engine's ~1 min tolerance. This mirrors SwiftAA's `JulianDay(date:)` so
/// values from the ephemeris adapter and the engine share one timescale.
public enum JulianDate {
    static let unixEpochJD = 2440587.5

    /// Julian Day for an absolute instant.
    public static func julianDay(from date: Date) -> Double {
        date.timeIntervalSince1970 / 86400.0 + unixEpochJD
    }

    /// Absolute instant for a Julian Day.
    public static func date(from julianDay: Double) -> Date {
        Date(timeIntervalSince1970: (julianDay - unixEpochJD) * 86400.0)
    }

    /// Julian Day for a wall-clock time in the given timezone.
    public static func julianDay(
        year: Int, month: Int, day: Int,
        hour: Int = 0, minute: Int = 0, second: Int = 0,
        timeZone: TimeZone
    ) -> Double? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = timeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let date = calendar.date(from: components) else { return nil }
        return julianDay(from: date)
    }

    /// Wall-clock components of a Julian Day in the given timezone.
    public static func components(julianDay: Double, timeZone: TimeZone) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date(from: julianDay)
        )
    }
}
