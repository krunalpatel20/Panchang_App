/// Devanagari and English name tables, parallel to PanchangNames (IAST-light).
/// Indices match exactly — same ordering, same count.
public extension PanchangNames {

    // MARK: - Devanagari

    static let tithiDevanagari: [String] = [
        "प्रतिपदा", "द्वितीया", "तृतीया", "चतुर्थी", "पञ्चमी",
        "षष्ठी", "सप्तमी", "अष्टमी", "नवमी", "दशमी",
        "एकादशी", "द्वादशी", "त्रयोदशी", "चतुर्दशी", "पूर्णिमा",
        "प्रतिपदा", "द्वितीया", "तृतीया", "चतुर्थी", "पञ्चमी",
        "षष्ठी", "सप्तमी", "अष्टमी", "नवमी", "दशमी",
        "एकादशी", "द्वादशी", "त्रयोदशी", "चतुर्दशी", "अमावस्या",
    ]

    static let nakshatraDevanagari: [String] = [
        "अश्विनी", "भरणी", "कृत्तिका", "रोहिणी", "मृगशिरा",
        "आर्द्रा", "पुनर्वसु", "पुष्य", "आश्लेषा", "मघा",
        "पूर्व फाल्गुनी", "उत्तर फाल्गुनी", "हस्त", "चित्रा", "स्वाती",
        "विशाखा", "अनुराधा", "ज्येष्ठा", "मूल", "पूर्वाषाढा",
        "उत्तराषाढा", "श्रवण", "धनिष्ठा", "शतभिषा",
        "पूर्वभाद्रपद", "उत्तरभाद्रपद", "रेवती",
    ]

    static let yogaDevanagari: [String] = [
        "विष्कम्भ", "प्रीति", "आयुष्मान्", "सौभाग्य", "शोभन",
        "अतिगण्ड", "सुकर्मा", "धृति", "शूल", "गण्ड",
        "वृद्धि", "ध्रुव", "व्याघात", "हर्षण", "वज्र",
        "सिद्धि", "व्यतीपात", "वरीयान्", "परिघ", "शिव",
        "सिद्ध", "साध्य", "शुभ", "शुक्ल", "ब्रह्म",
        "इन्द्र", "वैधृति",
    ]

    static let movableKaranasDevanagari: [String] = [
        "बव", "बालव", "कौलव", "तैतिल", "गरज", "वणिज", "विष्टि",
    ]

    static let varaDevanagari: [String] = [
        "रविवार", "सोमवार", "मंगलवार", "बुधवार", "गुरुवार", "शुक्रवार", "शनिवार",
    ]

    static let masaDevanagari: [String] = [
        "चैत्र", "वैशाख", "ज्येष्ठ", "आषाढ़", "श्रावण", "भाद्रपद",
        "आश्विन", "कार्तिक", "मार्गशीर्ष", "पौष", "माघ", "फाल्गुन",
    ]

    static let rituDevanagari: [String] = [
        "वसन्त", "ग्रीष्म", "वर्षा", "शरद्", "हेमन्त", "शिशिर",
    ]

    static func karanaDevanagari(halfTithiIndex n: Int) -> String {
        switch n {
        case 0: return "किंस्तुघ्न"
        case 57: return "शकुनि"
        case 58: return "चतुष्पाद"
        case 59: return "नाग"
        default: return movableKaranasDevanagari[(n - 1) % 7]
        }
    }

    // MARK: - English (simplified glosses)

    static let tithiEnglish: [String] = [
        "1st", "2nd", "3rd", "4th", "5th",
        "6th", "7th", "8th", "9th", "10th",
        "11th", "12th", "13th", "14th", "Full Moon",
        "1st", "2nd", "3rd", "4th", "5th",
        "6th", "7th", "8th", "9th", "10th",
        "11th", "12th", "13th", "14th", "New Moon",
    ]

    // Nakshatra, yoga, karana: IAST names are already widely understood in English contexts
    static let nakshatraEnglish: [String] = nakshatraDevanagari.map { _ in "" }  // fallback to IAST

    static let varaEnglish: [String] = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]

    static let masaEnglish: [String] = [
        "Chaitra", "Vaishakha", "Jyeshtha", "Ashadha", "Shravana", "Bhadrapada",
        "Ashwina", "Kartika", "Margashirsha", "Pausha", "Magha", "Phalguna",
    ]

    static let rituEnglish: [String] = [
        "Spring", "Summer", "Monsoon", "Autumn", "Pre-winter", "Winter",
    ]
}
