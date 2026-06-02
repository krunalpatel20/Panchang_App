import Foundation
import PanchangKit

/// Loads the bundled festival rule dataset and resolves festivals for a given panchang day.
struct FestivalService: Sendable {
    let rules: [FestivalRule]
    private let engine = FestivalEngine()

    static let shared: FestivalService = {
        let url = Bundle.main.url(forResource: "festivals", withExtension: "json")!
        let data = try! Data(contentsOf: url)
        let dataset = try! JSONDecoder().decode(FestivalDataset.self, from: data)
        return FestivalService(rules: dataset.festivals.map { $0.toRule() })
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

    func toRule() -> FestivalRule {
        let anchorValue: FestivalAnchor = {
            switch anchor.type {
            case "tithi":
                let paksha = FestivalAnchor.PakshaMatch(rawValue: anchor.paksha ?? "both") ?? .both
                return .tithi(number: anchor.number!, paksha: paksha)
            case "masaTithi":
                let paksha = FestivalAnchor.PakshaMatch(rawValue: anchor.paksha ?? "shukla") ?? .shukla
                return .masaTithi(masaIndex: anchor.masaIndex!, number: anchor.number!, paksha: paksha)
            case "vara":
                return .vara(index: anchor.varaIndex!)
            case "tithiVara":
                let paksha = FestivalAnchor.PakshaMatch(rawValue: anchor.paksha ?? "shukla") ?? .shukla
                return .tithiVara(tithiNumber: anchor.number!, paksha: paksha, varaIndex: anchor.varaIndex!)
            default:
                return .tithi(number: 1, paksha: .shukla)
            }
        }()
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
