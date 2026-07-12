import Foundation
import PanchangKit

/// Resolves festival occurrences for a given panchang day.
///
/// Festival rules are derived directly from `ContentStore`'s authored entries —
/// content.json (+ content-regional.json) is the single source of truth for which
/// festivals exist and how they're anchored. There is no separately maintained
/// festivals.json: a hand-kept duplicate of this data drifted from content.json in
/// practice (festivals existed in one file but not the other, masaIndex fixes applied
/// to one and not the other). Deriving rules from the same entries that supply the
/// voice content makes that class of drift structurally impossible.
struct FestivalService: Sendable {
    let rules: [FestivalRule]
    private let engine = FestivalEngine()

    static let shared: FestivalService = {
        let rules = ContentStore.shared.allEntries.compactMap { $0.toFestivalRule() }
        return FestivalService(rules: rules)
    }()

    private init(rules: [FestivalRule]) {
        self.rules = rules
    }

    func festivals(for day: PanchangDay) -> [FestivalOccurrence] {
        engine.festivals(for: day, rules: rules)
    }
}

// MARK: - ContentEntry → FestivalRule

private extension ContentEntry {
    /// Returns nil for entries that don't produce a standalone calendar occurrence
    /// (festivalType == nil, e.g. paksha_transition) or whose match can't be expressed
    /// as a FestivalAnchor.
    func toFestivalRule() -> FestivalRule? {
        guard let festivalType, let type = FestivalRule.FestivalType(rawValue: festivalType) else { return nil }
        guard let anchor = match.toFestivalAnchor() else { return nil }
        return FestivalRule(id: id, name: name, type: type, anchor: anchor, regions: regions)
    }
}

private extension ContentMatch {
    func toFestivalAnchor() -> FestivalAnchor? {
        let pakshaMatch: FestivalAnchor.PakshaMatch
        switch paksha {
        case .shukla: pakshaMatch = .shukla
        case .krishna: pakshaMatch = .krishna
        case .both, nil: pakshaMatch = .both
        }

        switch anchor {
        case .tithi:
            guard let tithi else { return nil }
            return .tithi(number: tithi, paksha: pakshaMatch)

        case .masaTithi:
            guard let tithi, let masaIndex else { return nil }
            return .masaTithi(masaIndex: masaIndex, number: tithi, paksha: pakshaMatch)

        case .solar:
            guard let rashiIndex else { return nil }
            return .solar(rashiIndex: rashiIndex)

        case .pakshaTransition:
            // Notification-text variant selector only — not a standalone calendar event.
            return nil

        case .paksha:
            // Ordinary-day hero copy only (A4) — not a standalone calendar event.
            return nil
        }
    }
}
