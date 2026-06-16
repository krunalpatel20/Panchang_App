import Foundation

/// The assembled, UI-free result for one (date, location, config). All instants are Julian
/// Days (UT); render them in `location.timeZone`. This is a value type so it is trivially
/// cacheable (SwiftData) and `Sendable`.
public struct PanchangDay: Sendable, Equatable {
    // Inputs
    public let year: Int
    public let month: Int
    public let day: Int
    public let location: GeoLocation
    public let config: CalendarConfig

    // Five limbs (each with end time, except vara)
    public let tithi: TithiInfo
    public let vara: VaraInfo
    public let nakshatra: NakshatraInfo
    public let yoga: YogaInfo
    public let karana: KaranaInfo

    // Month / year
    public let masa: MasaInfo
    public let yearInfo: YearInfo

    // Timings
    public let timings: DayTimings
    public let muhurtas: Muhurtas

    // Muhurta grid (M1): Choghadiya 16-segment grid + 24 planetary horas + Dur Muhurtam.
    public let choghadiya: Choghadiya
    public let horas: [Hora]
    public let durMuhurtam: [MuhurtaWindow]
    public let varjyam: [MuhurtaWindow]
    public let amritKalam: [MuhurtaWindow]

    /// The Moon's sidereal rashi (0…11) at sunrise — basis for Chandra Bala against a janma rashi.
    public let moonRashiIndex: Int
    /// The Sun's sidereal rashi (0…11) at sunrise — used for Sankranti (solar-transition) detection.
    /// Makara (Capricorn) = 9; changes roughly once per month.
    public let sunRashiIndex: Int
    /// True when `sunRashiIndex` differs from the previous civil day's — i.e. this is the
    /// Sankranti (solar ingress) day itself, not just any day within that rashi's ~30-day span.
    public let isSolarTransition: Bool

    // Edge-case reporting
    public let sunNeverRises: Bool
    public let sunNeverSets: Bool

    /// The lunar-month label to display for this day, honoring the preset's month-end
    /// convention (Krishna-paksha labels shift under Purnimanta; Shukla labels are identical).
    public var displayedMasaName: String {
        switch config.monthEnd {
        case .amanta: return masa.amantaName
        case .purnimanta: return masa.purnimantaName
        }
    }

    /// The Vikram Samvat year to display, honoring the preset's year anchor.
    public var displayedVikramSamvat: Int {
        switch config.yearAnchor {
        case .kartikadi: return yearInfo.vikramSamvatKartikadi
        case .chaitradi: return yearInfo.vikramSamvatChaitradi
        }
    }
}
