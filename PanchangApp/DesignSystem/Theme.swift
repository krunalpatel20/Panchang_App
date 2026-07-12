import SwiftUI

/// Warm-neutral text/paper palette plus the four accent colors shared across
/// both registers (editorial: Today, deep dives, onboarding; almanac: full
/// panchang, muhurta, calendar, kundli). Every color has a light/dark pair.
enum Palette {
    static let ink = Color(light: 0x1A1712, dark: 0xF2EEE6)
    static let inkStrong = Color(light: 0x34302A, dark: 0xE5E0D6)
    static let inkSecondary = Color(light: 0x6B6557, dark: 0xB3AC9D)
    static let inkMuted = Color(light: 0x8A8578, dark: 0x99927F)
    static let inkFaint = Color(light: 0xA39E90, dark: 0x847E6E)
    static let hairline = Color(light: 0xE7E2D8, dark: 0x33302A)

    static let paper = Color(light: 0xFFFFFF, dark: 0x161412)
    static let accent = Color(light: 0xB5552D, dark: 0xD4764E)       // terracotta
    static let auspicious = Color(light: 0x3E6B57, dark: 0x6FA089)  // quiet green
    static let festival = Color(light: 0xC8841A, dark: 0xE0A23F)    // lamp gold
    static let inauspicious = Color(light: 0xA03B2E, dark: 0xC4614F)
}

/// Day-state → accent/background pairing. Drives Today's hero and travels with
/// content into FestivalDetailView so the deep dive keeps the same mood.
enum DayMood: Equatable {
    case ordinary, ekadashi, festival

    var accent: Color {
        switch self {
        case .ordinary: return Palette.accent
        case .ekadashi: return Palette.auspicious
        case .festival: return Palette.festival
        }
    }

    var background: Color {
        switch self {
        case .ordinary: return Palette.paper
        case .ekadashi: return Color(light: 0xFBFCFB, dark: 0x141614)
        case .festival: return Color(light: 0xFFFBF2, dark: 0x1A1610)
        }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

// MARK: - Type tokens
//
// Use these everywhere; no raw `.system(size:)` outside DesignSystem once
// Part B of SPEC-conformity-theme.md lands (Settings/LocationSearchView are
// the deliberate stock-List exception).

extension Font {
    /// Today hero only. 28pt normally, 33pt on festival days.
    static func heroSerif(festival: Bool) -> Font {
        .system(size: festival ? 33 : 28, design: .serif)
    }
    /// Editorial screen titles, deep-dive name.
    static let titleSerif = Font.system(size: 22, design: .serif)
    /// List primary text — Coming up rows, festival rows.
    static let rowSerif = Font.system(size: 18, design: .serif)
    /// Deep-dive paragraphs, onboarding prose. Pair with `.lineSpacing(6)` at the call site.
    static let bodyProse = Font.system(size: 17, design: .serif)
    /// Sub-lines, explanatory text. Spec range is 15–16.5; default covers the common case.
    static func bodySans(_ size: CGFloat = 15.5) -> Font { .system(size: size) }
    /// Times, numerics.
    static let dataSans = Font.system(size: 15).monospacedDigit()
    /// ALL section headers — pair with `EditorialSectionHeader`, not raw.
    static let trackedCaption = Font.system(size: 12.5)
    /// Taglines, "in N days", metadata.
    static let tagSans = Font.system(size: 13.5)
}
