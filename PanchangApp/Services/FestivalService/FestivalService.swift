import Foundation
import PanchangKit

/// Loads the bundled festival rule dataset and resolves festivals for a given panchang day.
struct FestivalService: Sendable {
    let rules: [FestivalRule]
    private let engine = FestivalEngine()

    static let shared: FestivalService = {
        guard let url = Bundle.main.url(forResource: "festivals", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dataset = try? JSONDecoder().decode(FestivalDataset.self, from: data) else {
            assertionFailure("festivals.json missing or malformed")
            return FestivalService(rules: [])
        }
        return FestivalService(rules: dataset.festivals.compactMap { $0.toRule() })
    }()

    private init(rules: [FestivalRule]) {
        self.rules = rules
    }

    func festivals(for day: PanchangDay) -> [FestivalOccurrence] {
        engine.festivals(for: day, rules: rules)
    }
}

// MARK: - JSON DTO

private struct FestivalDataset: Codable {
    let version: String
    let festivals: [FestivalDTO]
}

private struct FestivalDTO: Codable {
    let id: String
    let name: String
    let type: String
    let anchor: AnchorDTO
    let regions: [String]

    /// Returns nil (the rule is skipped) for unknown anchor types or missing fields, rather
    /// than crashing or inventing a default anchor that would fire on the wrong days.
    func toRule() -> FestivalRule? {
        let anchorValue: FestivalAnchor?
        switch anchor.type {
        case "tithi":
            let paksha = FestivalAnchor.PakshaMatch(rawValue: anchor.paksha ?? "both") ?? .both
            anchorValue = anchor.number.map { .tithi(number: $0, paksha: paksha) }
        case "masaTithi":
            let paksha = FestivalAnchor.PakshaMatch(rawValue: anchor.paksha ?? "shukla") ?? .shukla
            if let masaIndex = anchor.masaIndex, let number = anchor.number {
                anchorValue = .masaTithi(masaIndex: masaIndex, number: number, paksha: paksha)
            } else {
                anchorValue = nil
            }
        case "vara":
            anchorValue = anchor.varaIndex.map { .vara(index: $0) }
        case "tithiVara":
            let paksha = FestivalAnchor.PakshaMatch(rawValue: anchor.paksha ?? "shukla") ?? .shukla
            if let number = anchor.number, let varaIndex = anchor.varaIndex {
                anchorValue = .tithiVara(tithiNumber: number, paksha: paksha, varaIndex: varaIndex)
            } else {
                anchorValue = nil
            }
        default:
            anchorValue = nil
        }
        guard let anchorValue else {
            assertionFailure("festivals.json: skipping malformed rule '\(id)' (anchor type '\(anchor.type)')")
            return nil
        }
        let festType = FestivalRule.FestivalType(rawValue: type) ?? .observance
        return FestivalRule(id: id, name: name, type: festType, anchor: anchorValue, regions: regions)
    }
}

private struct AnchorDTO: Codable {
    let type: String
    let number: Int?
    let paksha: String?
    let masaIndex: Int?
    let varaIndex: Int?
}
