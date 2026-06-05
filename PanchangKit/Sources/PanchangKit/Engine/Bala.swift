import Foundation

/// Tara Bala — the day's nakshatra counted from the user's janma (birth) nakshatra, giving one
/// of 9 taras with an auspicious/inauspicious quality. Requires the janma nakshatra (Settings).
public struct TaraBala: Sendable, Equatable {
    public let index: Int          // 0…8, 0 = Janma
    public let name: String
    public let count: Int          // 1…27, the raw count from janma to the day's nakshatra
    public let isAuspicious: Bool

    /// Auspicious taras: Sampat(1), Kshema(3), Sadhaka(5), Mitra(7), Ati Mitra(8).
    /// Inauspicious: Janma(0), Vipat(2), Pratyari(4), Vadha(6).
    private static let auspicious: Set<Int> = [1, 3, 5, 7, 8]

    /// - Parameters:
    ///   - janmaNakshatra: birth nakshatra index 0…26.
    ///   - dayNakshatra: the day's nakshatra index 0…26.
    public static func compute(janmaNakshatra: Int, dayNakshatra: Int) -> TaraBala {
        let count = ((dayNakshatra - janmaNakshatra + 27) % 27) + 1   // 1…27
        let index = (count - 1) % 9
        return TaraBala(index: index, name: PanchangNames.tara[index], count: count,
                        isAuspicious: auspicious.contains(index))
    }
}

/// Chandra Bala — strength of the Moon by its rashi relative to the user's janma rashi. The Moon
/// is favourable when it transits the 1st, 3rd, 6th, 7th, 10th or 11th sign from the janma rashi.
/// Requires the janma rashi (Settings).
public struct ChandraBala: Sendable, Equatable {
    public let house: Int          // 1…12, position of the Moon's rashi from the janma rashi
    public let moonRashi: Int      // 0…11
    public let isAuspicious: Bool

    private static let favourable: Set<Int> = [1, 3, 6, 7, 10, 11]

    /// - Parameters:
    ///   - janmaRashi: birth Moon sign index 0…11.
    ///   - moonRashi: the day's Moon rashi index 0…11.
    public static func compute(janmaRashi: Int, moonRashi: Int) -> ChandraBala {
        let house = ((moonRashi - janmaRashi + 12) % 12) + 1   // 1…12
        return ChandraBala(house: house, moonRashi: moonRashi, isAuspicious: favourable.contains(house))
    }
}
