import Foundation

/// Navamsha (D9) — the ninth divisional chart. Each rashi (30°) is split into nine
/// navamshas of 3°20′ each; the 108 navamshas map continuously around the zodiac.
///
/// The continuous floor formula reproduces the classical movable/fixed/dual starting-sign
/// rule exactly: a movable sign's first navamsha is the sign itself, a fixed sign's is the
/// 9th from it, a dual sign's is the 5th — all of which fall out of dividing the full circle
/// into 108 equal arcs. Verified: Aries 0°→Aries, Taurus 30°→Capricorn, Gemini 60°→Libra.
enum Navamsha {
    static let navamshaArc = 30.0 / 9.0   // 3°20′

    /// Navamsha rashi (zodiac sign) index 0…11 for a sidereal ecliptic longitude.
    static func rashi(siderealLongitude: Double) -> Int {
        let lon = AngleMath.normalize360(siderealLongitude)
        return Int(floor(lon / navamshaArc).truncatingRemainder(dividingBy: 12))
    }
}
