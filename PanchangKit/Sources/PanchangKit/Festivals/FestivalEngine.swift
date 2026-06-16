/// Matches festival rules against a computed panchang day.
/// This is pure, stateless logic — no I/O, no Calendar dependency.
public struct FestivalEngine: Sendable {
    public init() {}

    /// Returns all festivals that apply to this panchang day.
    public func festivals(for day: PanchangDay, rules: [FestivalRule]) -> [FestivalOccurrence] {
        rules.compactMap { rule in
            matches(rule: rule, day: day) ? FestivalOccurrence(rule: rule) : nil
        }
    }

    private func matches(rule: FestivalRule, day: PanchangDay) -> Bool {
        switch rule.anchor {
        case .tithi(let number, let paksha):
            return tithiMatches(day: day, number: number, paksha: paksha)

        case .masaTithi(let masaIndex, let number, let paksha):
            // masaIndex is 0-based Amanta masa (0=Chaitra … 11=Phalgun)
            guard day.masa.amantaIndex == masaIndex else { return false }
            return tithiMatches(day: day, number: number, paksha: paksha)

        case .vara(let index):
            return day.vara.index == index

        case .tithiVara(let tithiNumber, let paksha, let varaIndex):
            return tithiMatches(day: day, number: tithiNumber, paksha: paksha)
                && day.vara.index == varaIndex

        case .solar(let rashiIndex):
            return day.isSolarTransition && day.sunRashiIndex == rashiIndex
        }
    }

    // tithiNumber is 1-based (1=Pratipada … 15=Purnima/Amavasya) per paksha
    private func tithiMatches(day: PanchangDay, number: Int, paksha: FestivalAnchor.PakshaMatch) -> Bool {
        // TithiInfo.index is 0-based: 0…14 = Shukla Pratipada…Purnima, 15…29 = Krishna
        // Pratipada…Amavasya. Convert the rule's 1-based number to the index in its paksha.
        let expectedIndex: Int
        switch paksha {
        case .shukla:
            expectedIndex = number - 1          // Shukla 1 → index 0 … Shukla 15 → index 14
        case .krishna:
            expectedIndex = 15 + (number - 1)  // Krishna 1 → index 15 … Krishna 15 → index 29
        case .both:
            // Match against either paksha
            let shuklaIdx = number - 1
            let krishnaIdx = 15 + (number - 1)
            return day.tithi.index == shuklaIdx || day.tithi.index == krishnaIdx
        }
        guard day.tithi.index == expectedIndex else { return false }
        switch paksha {
        case .shukla: return day.tithi.paksha == .shukla
        case .krishna: return day.tithi.paksha == .krishna
        case .both: return true
        }
    }
}
