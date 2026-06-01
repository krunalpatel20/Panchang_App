import Foundation

/// Canonical Sanskrit (IAST-light transliteration) name tables. Spellings follow the
/// validation authority (drikpanchang.com). Devanagari + Gujarati tables are added in M6;
/// keeping names as data (not logic) is required by SPEC §8.
public enum PanchangNames {
    /// 30 tithi names, index 0 = Shukla Pratipada … 14 = Purnima, 15 = Krishna Pratipada … 29 = Amavasya.
    public static let tithi: [String] = [
        "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
        "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
        "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Purnima",
        "Pratipada", "Dwitiya", "Tritiya", "Chaturthi", "Panchami",
        "Shashthi", "Saptami", "Ashtami", "Navami", "Dashami",
        "Ekadashi", "Dwadashi", "Trayodashi", "Chaturdashi", "Amavasya",
    ]

    /// 27 nakshatra names, index 0 = Ashwini.
    public static let nakshatra: [String] = [
        "Ashwini", "Bharani", "Krittika", "Rohini", "Mrigashira",
        "Ardra", "Punarvasu", "Pushya", "Ashlesha", "Magha",
        "Purva Phalguni", "Uttara Phalguni", "Hasta", "Chitra", "Swati",
        "Vishakha", "Anuradha", "Jyeshtha", "Mula", "Purva Ashadha",
        "Uttara Ashadha", "Shravana", "Dhanishta", "Shatabhisha",
        "Purva Bhadrapada", "Uttara Bhadrapada", "Revati",
    ]

    /// 27 yoga names, index 0 = Vishkambha.
    public static let yoga: [String] = [
        "Vishkambha", "Priti", "Ayushman", "Saubhagya", "Shobhana",
        "Atiganda", "Sukarma", "Dhriti", "Shula", "Ganda",
        "Vriddhi", "Dhruva", "Vyaghata", "Harshana", "Vajra",
        "Siddhi", "Vyatipata", "Variyana", "Parigha", "Shiva",
        "Siddha", "Sadhya", "Shubha", "Shukla", "Brahma",
        "Indra", "Vaidhriti",
    ]

    /// The 7 repeating (chara) karanas, cycled through the lunar month.
    public static let movableKaranas: [String] = [
        "Bava", "Balava", "Kaulava", "Taitila", "Garaja", "Vanija", "Vishti",
    ]

    /// 7 weekday (vara) names, index 0 = Sunday (matches Gregorian weekday ordering).
    public static let vara: [String] = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]

    /// 12 lunar-month (masa) names, index 0 = Chaitra (Sanskrit forms).
    public static let masa: [String] = [
        "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
        "Ashwina", "Kartika", "Margashirsha", "Pausha", "Magha", "Phalguna",
    ]

    /// 6 ritu (seasons), each spanning two solar months. index 0 = Vasant (spring).
    public static let ritu: [String] = [
        "Vasant", "Grishma", "Varsha", "Sharad", "Hemant", "Shishir",
    ]

    /// Resolve the karana name for a half-tithi index 0…59 within the lunar month.
    /// 0 = Kimstughna (fixed), 1…56 cycle the 7 movable karanas, 57/58/59 = the fixed
    /// Shakuni / Chatushpada / Naga.
    public static func karana(halfTithiIndex n: Int) -> String {
        switch n {
        case 0: return "Kimstughna"
        case 57: return "Shakuni"
        case 58: return "Chatushpada"
        case 59: return "Naga"
        default: return movableKaranas[(n - 1) % 7]
        }
    }
}
