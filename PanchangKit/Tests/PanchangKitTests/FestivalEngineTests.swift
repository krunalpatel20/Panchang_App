import Testing
@testable import PanchangKit

/// Pure rule-matching tests for `FestivalEngine` against synthetic days. The tithi index
/// convention is 0…14 = Shukla Pratipada…Purnima, 15…29 = Krishna Pratipada…Amavasya.
@Suite("FestivalEngine")
struct FestivalEngineTests {
    private let engine = FestivalEngine()

    /// A minimal PanchangDay: only the fields festival rules read (tithi, vara, masa) carry
    /// real values; everything else is inert filler.
    private func day(tithiIndex: Int, varaIndex: Int = 1, amantaMasaIndex: Int = 0,
                      sunRashiIndex: Int = 0, isSolarTransition: Bool = false) -> PanchangDay {
        let emptyWindow = MuhurtaWindow(start: nil, end: nil)
        return PanchangDay(
            year: 2026, month: 1, day: 1,
            location: GeoLocation(latitude: 0, longitude: 0, timeZoneIdentifier: "UTC"),
            config: .gujaratiWestern,
            tithi: TithiInfo(
                index: tithiIndex,
                name: PanchangNames.tithi[tithiIndex],
                paksha: tithiIndex < 15 ? .shukla : .krishna,
                endJulianDay: 0
            ),
            vara: VaraInfo(index: varaIndex, name: PanchangNames.vara[varaIndex]),
            nakshatra: NakshatraInfo(index: 0, name: PanchangNames.nakshatra[0], endJulianDay: 0),
            yoga: YogaInfo(index: 0, name: PanchangNames.yoga[0], endJulianDay: 0),
            karana: KaranaInfo(index: 0, name: PanchangNames.karana(halfTithiIndex: 0), endJulianDay: 0),
            masa: MasaInfo(
                amantaIndex: amantaMasaIndex,
                purnimantaIndex: amantaMasaIndex,
                amantaName: PanchangNames.masa[amantaMasaIndex],
                purnimantaName: PanchangNames.masa[amantaMasaIndex],
                isAdhika: false, isKshaya: false
            ),
            yearInfo: YearInfo(
                vikramSamvatChaitradi: 2082, vikramSamvatKartikadi: 2082,
                rituIndex: 0, rituName: PanchangNames.ritu[0], ayana: "Uttarayana"
            ),
            timings: DayTimings(sunrise: nil, sunset: nil, moonrise: nil, moonset: nil,
                                sunNeverRises: false, sunNeverSets: false),
            muhurtas: Muhurtas(rahuKalam: emptyWindow, yamaganda: emptyWindow, gulika: emptyWindow,
                               abhijit: emptyWindow, brahmaMuhurta: emptyWindow),
            choghadiya: Choghadiya(day: [], night: []),
            horas: [],
            durMuhurtam: [],
            varjyam: [],
            amritKalam: [],
            moonRashiIndex: 0,
            sunRashiIndex: sunRashiIndex,
            isSolarTransition: isSolarTransition,
            sunNeverRises: false,
            sunNeverSets: false
        )
    }

    private func matches(_ rule: FestivalRule, tithiIndex: Int, varaIndex: Int = 1, masaIndex: Int = 0) -> Bool {
        !engine.festivals(
            for: day(tithiIndex: tithiIndex, varaIndex: varaIndex, amantaMasaIndex: masaIndex),
            rules: [rule]
        ).isEmpty
    }

    // MARK: - Shukla paksha

    @Test func shuklaPratipadaMatchesIndex0() {
        let rule = FestivalRule(id: "t", name: "t", type: .observance,
                                anchor: .tithi(number: 1, paksha: .shukla))
        #expect(matches(rule, tithiIndex: 0))
        #expect(!matches(rule, tithiIndex: 1))
        #expect(!matches(rule, tithiIndex: 15))   // Krishna Pratipada must not match
    }

    @Test func purnimaMatchesIndex14() {
        let rule = FestivalRule(id: "purnima", name: "Purnima", type: .observance,
                                anchor: .tithi(number: 15, paksha: .shukla))
        #expect(matches(rule, tithiIndex: 14))
        #expect(!matches(rule, tithiIndex: 29))
    }

    // MARK: - Krishna paksha (regression: was off by one, Krishna n matched index 14+n−1)

    @Test func krishnaPratipadaMatchesIndex15() {
        let rule = FestivalRule(id: "t", name: "t", type: .observance,
                                anchor: .tithi(number: 1, paksha: .krishna))
        #expect(matches(rule, tithiIndex: 15))
        #expect(!matches(rule, tithiIndex: 14))   // Purnima must not match
        #expect(!matches(rule, tithiIndex: 0))
    }

    @Test func amavasyaMatchesIndex29() {
        let rule = FestivalRule(id: "amavasya", name: "Amavasya", type: .observance,
                                anchor: .tithi(number: 15, paksha: .krishna))
        #expect(matches(rule, tithiIndex: 29))
        #expect(!matches(rule, tithiIndex: 28))   // Krishna Chaturdashi must not match
    }

    @Test func krishnaEkadashiMatchesIndex25() {
        let rule = FestivalRule(id: "ekadashi", name: "Ekadashi", type: .vrat,
                                anchor: .tithi(number: 11, paksha: .krishna))
        #expect(matches(rule, tithiIndex: 25))
        #expect(!matches(rule, tithiIndex: 24))   // Krishna Dashami must not match
    }

    @Test func janmashtamiMatchesKrishnaAshtamiInShravana() {
        // masaIndex 4 = Shravana (amanta), Krishna 8 = index 22
        let rule = FestivalRule(id: "janmashtami", name: "Janmashtami", type: .festival,
                                anchor: .masaTithi(masaIndex: 4, number: 8, paksha: .krishna))
        #expect(matches(rule, tithiIndex: 22, masaIndex: 4))
        #expect(!matches(rule, tithiIndex: 21, masaIndex: 4))  // Krishna Saptami
        #expect(!matches(rule, tithiIndex: 22, masaIndex: 5))  // wrong masa
    }

    @Test func diwaliMatchesKartikaAmavasya() {
        // masaIndex 7 = Ashwin (amanta convention used by the dataset), Krishna 15 = index 29
        let rule = FestivalRule(id: "diwali", name: "Diwali", type: .festival,
                                anchor: .masaTithi(masaIndex: 7, number: 15, paksha: .krishna))
        #expect(matches(rule, tithiIndex: 29, masaIndex: 7))
        #expect(!matches(rule, tithiIndex: 28, masaIndex: 7))  // Kali Chaudas day
    }

    // MARK: - Both paksha

    @Test func bothPakshaMatchesEitherSide() {
        let rule = FestivalRule(id: "chaturthi", name: "Chaturthi", type: .vrat,
                                anchor: .tithi(number: 4, paksha: .both))
        #expect(matches(rule, tithiIndex: 3))    // Shukla Chaturthi
        #expect(matches(rule, tithiIndex: 18))   // Krishna Chaturthi
        #expect(!matches(rule, tithiIndex: 17))  // Krishna Tritiya
        #expect(!matches(rule, tithiIndex: 4))
    }

    // MARK: - Vara and tithi+vara

    @Test func varaRuleMatchesWeekdayOnly() {
        let rule = FestivalRule(id: "somvar", name: "Somvar", type: .vrat,
                                anchor: .vara(index: 1))
        #expect(matches(rule, tithiIndex: 5, varaIndex: 1))
        #expect(!matches(rule, tithiIndex: 5, varaIndex: 2))
    }

    @Test func tithiVaraRequiresBoth() {
        let rule = FestivalRule(id: "pradosh-som", name: "Som Pradosh", type: .vrat,
                                anchor: .tithiVara(tithiNumber: 13, paksha: .krishna, varaIndex: 1))
        #expect(matches(rule, tithiIndex: 27, varaIndex: 1))   // Krishna Trayodashi, Monday
        #expect(!matches(rule, tithiIndex: 27, varaIndex: 2))
        #expect(!matches(rule, tithiIndex: 26, varaIndex: 1))
    }

    // MARK: - Solar (Sankranti transition, not whole-month membership)

    @Test func solarMatchesOnlyTheTransitionDay() {
        let rule = FestivalRule(id: "makar_sankranti", name: "Makar Sankranti", type: .festival,
                                anchor: .solar(rashiIndex: 9))
        let transitionDay = day(tithiIndex: 5, sunRashiIndex: 9, isSolarTransition: true)
        let midMonthDay = day(tithiIndex: 12, sunRashiIndex: 9, isSolarTransition: false)
        #expect(!engine.festivals(for: transitionDay, rules: [rule]).isEmpty)
        #expect(engine.festivals(for: midMonthDay, rules: [rule]).isEmpty)
    }

    @Test func solarRequiresMatchingRashi() {
        let rule = FestivalRule(id: "makar_sankranti", name: "Makar Sankranti", type: .festival,
                                anchor: .solar(rashiIndex: 9))
        let wrongRashiTransition = day(tithiIndex: 5, sunRashiIndex: 8, isSolarTransition: true)
        #expect(engine.festivals(for: wrongRashiTransition, rules: [rule]).isEmpty)
    }
}
