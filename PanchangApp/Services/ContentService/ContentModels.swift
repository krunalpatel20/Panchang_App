import Foundation

// MARK: - Core content entry

struct ContentEntry: Sendable, Identifiable, Codable {
    let id: String
    let kind: ContentKind
    let tier: Int // 1 = major festival … 5 = named tithi
    let match: ContentMatch
    let variants: [ContentVariant]
    let voice: VoiceLayers
    let triggers: [NotificationTrigger]
    let action: ContentAction?
    let regions: [String] // [] = everywhere
    let audioScript: String? // reserved, V2
    let almanacBlurb: String? // reserved, print almanac

    enum ContentKind: String, Sendable, Codable {
        case cycle, festival, paksha, tithi
    }
}

// MARK: - Match

struct ContentMatch: Sendable, Codable {
    enum Anchor: String, Sendable, Codable {
        case tithi, masaTithi, pakshaTransition, solar
    }
    let anchor: Anchor
    let tithi: Int?
    let paksha: Paksha?
    let masaIndex: Int?
    let rashiIndex: Int? // solar anchor only — 0=Mesha … 9=Makara … 11=Meena

    enum Paksha: String, Sendable, Codable {
        case shukla, krishna, both
    }
}

struct ContentVariant: Sendable, Codable {
    let id: String
    let match: ContentMatch
    let voice: VoiceLayers?
    /// Overrides only the morning text, inheriting everything else from the base entry.
    let morningOverride: VoiceLayer?
    let triggers: [NotificationTrigger]?
    let action: ContentAction?
}

// MARK: - Voice layers

struct VoiceLayers: Sendable, Codable {
    let advance: VoiceLayer?
    let eve: VoiceLayer?
    let morning: VoiceLayer
    let deepDive: DeepDive
    let food: FoodNote // non-optional — structurally enforced
}

struct VoiceLayer: Sendable, Codable {
    let text: String
    let daysBefore: Int? // for advance only
}

// MARK: - Deep dive (5-para Part Seven structure)

struct DeepDive: Sendable, Codable {
    let whatItIs: String
    let mythology: String
    let history: String
    let regional: String
    let whatToDo: String
}

// MARK: - Food

struct FoodNote: Sendable, Codable {
    let note: String
    let recipeLink: URL?
}

// MARK: - Action affordance

struct ContentAction: Sendable, Codable {
    enum Kind: String, Sendable, Codable {
        case call, addReminder, openMaps, note
    }
    let kind: Kind
    let label: String
    let payload: String? // phone number / address / note template
}
