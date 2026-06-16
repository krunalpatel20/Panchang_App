import Foundation

enum NotificationTrigger: Sendable, Codable {
    case advance(daysBefore: Int)
    case eve(time: CodableDateComponents)
    case morning(time: CodableDateComponents)
    case midnight
    case dayOffset(Int, label: String)

    // MARK: - Codable support

    private enum CodingKeys: String, CodingKey {
        case type, daysBefore, time, offset, label
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "advance":
            self = .advance(daysBefore: try c.decode(Int.self, forKey: .daysBefore))
        case "eve":
            self = .eve(time: try c.decode(CodableDateComponents.self, forKey: .time))
        case "morning":
            self = .morning(time: try c.decode(CodableDateComponents.self, forKey: .time))
        case "midnight":
            self = .midnight
        case "dayOffset":
            self = .dayOffset(
                try c.decode(Int.self, forKey: .offset),
                label: try c.decode(String.self, forKey: .label)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: c, debugDescription: "Unknown trigger type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .advance(let days):
            try c.encode("advance", forKey: .type)
            try c.encode(days, forKey: .daysBefore)
        case .eve(let time):
            try c.encode("eve", forKey: .type)
            try c.encode(time, forKey: .time)
        case .morning(let time):
            try c.encode("morning", forKey: .type)
            try c.encode(time, forKey: .time)
        case .midnight:
            try c.encode("midnight", forKey: .type)
        case .dayOffset(let offset, let label):
            try c.encode("dayOffset", forKey: .type)
            try c.encode(offset, forKey: .offset)
            try c.encode(label, forKey: .label)
        }
    }
}

// DateComponents isn't Codable natively; wrap hour/minute only.
struct CodableDateComponents: Sendable, Codable {
    let hour: Int
    let minute: Int

    var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }
}
