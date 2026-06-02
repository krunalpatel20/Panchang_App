import PanchangKit

/// Resolves Sanskrit term display in the user's chosen script mode.
/// Uses the raw index from each PanchangDay limb to look up the right table.
struct ScriptRenderer: Sendable {
    let mode: String   // "transliteration" | "devanagari" | "english"

    // MARK: - Limb names

    func tithiName(index: Int) -> String {
        guard (0..<30).contains(index) else { return "–" }
        switch mode {
        case "devanagari": return PanchangNames.tithiDevanagari[index]
        case "english":    return PanchangNames.tithiEnglish[index]
        default:           return PanchangNames.tithi[index]
        }
    }

    func nakshatraName(index: Int) -> String {
        guard (0..<27).contains(index) else { return "–" }
        switch mode {
        case "devanagari": return PanchangNames.nakshatraDevanagari[index]
        default:           return PanchangNames.nakshatra[index]   // same for english
        }
    }

    func yogaName(index: Int) -> String {
        guard (0..<27).contains(index) else { return "–" }
        switch mode {
        case "devanagari": return PanchangNames.yogaDevanagari[index]
        default:           return PanchangNames.yoga[index]
        }
    }

    func karanaName(halfTithiIndex n: Int) -> String {
        switch mode {
        case "devanagari": return PanchangNames.karanaDevanagari(halfTithiIndex: n)
        default:           return PanchangNames.karana(halfTithiIndex: n)
        }
    }

    func varaName(index: Int) -> String {
        guard (0..<7).contains(index) else { return "–" }
        switch mode {
        case "devanagari": return PanchangNames.varaDevanagari[index]
        case "english":    return PanchangNames.varaEnglish[index]
        default:           return PanchangNames.vara[index]
        }
    }

    func masaName(amantaIndex: Int) -> String {
        guard (0..<12).contains(amantaIndex) else { return "–" }
        switch mode {
        case "devanagari": return PanchangNames.masaDevanagari[amantaIndex]
        case "english":    return PanchangNames.masaEnglish[amantaIndex]
        default:           return PanchangNames.masa[amantaIndex]
        }
    }

    func rituName(index: Int) -> String {
        guard (0..<6).contains(index) else { return "–" }
        switch mode {
        case "devanagari": return PanchangNames.rituDevanagari[index]
        case "english":    return PanchangNames.rituEnglish[index]
        default:           return PanchangNames.ritu[index]
        }
    }

    func paksha(_ paksha: Paksha) -> String {
        switch mode {
        case "devanagari":
            return paksha == .shukla ? "शुक्ल" : "कृष्ण"
        case "english":
            return paksha == .shukla ? "Waxing" : "Waning"
        default:
            return paksha.rawValue
        }
    }
}
