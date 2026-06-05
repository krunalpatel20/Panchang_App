import Testing
import Foundation
@testable import PanchangKit

struct BalaTests {

    @Test func taraBalaCountingAndQuality() {
        // Same nakshatra as janma → count 1 → Janma tara (inauspicious).
        let janma = TaraBala.compute(janmaNakshatra: 5, dayNakshatra: 5)
        #expect(janma.count == 1)
        #expect(janma.index == 0)
        #expect(janma.name == "Janma")
        #expect(janma.isAuspicious == false)

        // One ahead → count 2 → Sampat (auspicious).
        let sampat = TaraBala.compute(janmaNakshatra: 5, dayNakshatra: 6)
        #expect(sampat.count == 2 && sampat.index == 1 && sampat.isAuspicious)

        // Wrap-around: janma=25, day=2 → count = (2-25+27)%27+1 = 5 → Pratyari (index 4, inauspicious).
        let wrap = TaraBala.compute(janmaNakshatra: 25, dayNakshatra: 2)
        #expect(wrap.count == 5 && wrap.index == 4 && !wrap.isAuspicious)

        // 10th nakshatra ahead → count 10 → index (10-1)%9 = 0 → Janma again (the cycle repeats every 9).
        let cycle = TaraBala.compute(janmaNakshatra: 0, dayNakshatra: 9)
        #expect(cycle.count == 10 && cycle.index == 0)
    }

    @Test func chandraBalaHousesAndQuality() {
        // Same rashi → house 1 → favourable.
        let h1 = ChandraBala.compute(janmaRashi: 3, moonRashi: 3)
        #expect(h1.house == 1 && h1.isAuspicious)

        // 4th house (janma+3) → unfavourable.
        let h4 = ChandraBala.compute(janmaRashi: 3, moonRashi: 6)
        #expect(h4.house == 4 && !h4.isAuspicious)

        // Wrap: janma=10, moon=2 → house = (2-10+12)%12+1 = 5 → unfavourable.
        let h5 = ChandraBala.compute(janmaRashi: 10, moonRashi: 2)
        #expect(h5.house == 5 && !h5.isAuspicious)

        // 11th house favourable.
        let h11 = ChandraBala.compute(janmaRashi: 0, moonRashi: 10)
        #expect(h11.house == 11 && h11.isAuspicious)
    }

    @Test func moonRashiIsInRange() {
        let loc = GeoLocation(latitude: 37.3382, longitude: -121.8863, timeZoneIdentifier: "America/Los_Angeles")
        let day = Panchang().compute(year: 2026, month: 5, day: 28, location: loc, config: .gujaratiWestern)
        #expect(day.moonRashiIndex >= 0 && day.moonRashiIndex < 12)
    }
}
