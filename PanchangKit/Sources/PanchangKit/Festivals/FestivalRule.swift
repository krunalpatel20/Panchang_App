import Foundation

/// How a festival is anchored to the panchang.
public enum FestivalAnchor: Sendable {
    /// Occurs on a specific tithi (and optional paksha).
    case tithi(number: Int, paksha: PakshaMatch)
    /// Occurs on a specific tithi within a specific lunar masa.
    case masaTithi(masaIndex: Int, number: Int, paksha: PakshaMatch)
    /// Occurs on a specific weekday (vara index 0=Sun … 6=Sat).
    case vara(index: Int)
    /// Tithi + vara combination (e.g. Pradosh on Shivratri weekday).
    case tithiVara(tithiNumber: Int, paksha: PakshaMatch, varaIndex: Int)

    public enum PakshaMatch: String, Sendable {
        case shukla, krishna, both
    }
}

/// A single festival/vrat rule.
public struct FestivalRule: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let type: FestivalType
    public let anchor: FestivalAnchor
    /// Empty = applies everywhere; otherwise restrict by region tag.
    public let regions: [String]

    public enum FestivalType: String, Sendable {
        case festival, vrat, observance
    }

    public init(id: String, name: String, type: FestivalType,
                anchor: FestivalAnchor, regions: [String] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.anchor = anchor
        self.regions = regions
    }
}

/// A resolved festival occurrence for a given panchang day.
public struct FestivalOccurrence: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let type: FestivalRule.FestivalType

    public init(rule: FestivalRule) {
        self.id = rule.id
        self.name = rule.name
        self.type = rule.type
    }
}
