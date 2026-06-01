import Foundation

/// How the lunar month ends — drives the month label for Krishna-paksha days (SPEC §8).
public enum MonthEndConvention: String, Sendable, Codable {
    case amanta       // month ends at Amavasya (new moon)
    case purnimanta   // month ends at Purnima (full moon)
}

/// Which lunar new-year anchor drives the Samvat increment (SPEC §8).
public enum YearAnchor: String, Sendable, Codable {
    case kartikadi    // year starts Kartik Shukla 1 (Gujarati / Western)
    case chaitradi    // year starts Chaitra Shukla 1 (North Indian)
}

/// Tradition preset. Exposed to users as a named preset (not independent toggles) to prevent
/// invalid combinations, per SPEC §8.
public struct CalendarConfig: Sendable, Equatable, Codable {
    public let monthEnd: MonthEndConvention
    public let yearAnchor: YearAnchor

    public init(monthEnd: MonthEndConvention, yearAnchor: YearAnchor) {
        self.monthEnd = monthEnd
        self.yearAnchor = yearAnchor
    }

    /// Gujarati / Western Indian (default): Amanta months, Kartikadi year.
    public static let gujaratiWestern = CalendarConfig(monthEnd: .amanta, yearAnchor: .kartikadi)
    /// North Indian: Purnimanta months, Chaitradi year.
    public static let northIndian = CalendarConfig(monthEnd: .purnimanta, yearAnchor: .chaitradi)
}
