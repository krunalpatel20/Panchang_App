import Testing
import Foundation
import PanchangKit
@testable import PanchangApp

/// Covers the WP-2 acceptance criteria from SPEC-conformity-theme.md: A1.1 (advance/advance2/eve/
/// dayOffset notification-body selection), A3 (`{{masa}}`/`{{vsYear}}` token substitution), and A4
/// (the new `paksha`-only match anchor). These exercise `ContentResolver`'s matching/substitution/
/// body-selection helpers directly with synthetic `ContentMatch`/`VoiceLayers` values rather than via
/// `ContentStore.shared` — the real content.json entries that would exercise this end-to-end
/// (Ganesh Chaturthi's advance2/offsets, the two new paksha cycle entries, the {{masa}}/{{vsYear}}
/// sentences) are WP-6's responsibility and land after this engine work.
struct ContentResolverTests {
    private let resolver = ContentResolver()

    /// Washington DC — the same reference location PresetTests.swift uses, and (unlike some
    /// west-coast timezones) one where Kartik Purnima 2026 isn't a kshaya (skipped) tithi.
    private let wdc = GeoLocation(latitude: 38.895, longitude: -77.036, timeZoneIdentifier: "America/New_York")

    private func compute(_ y: Int, _ m: Int, _ d: Int, _ config: CalendarConfig = .gujaratiWestern) -> PanchangDay {
        PanchangService().compute(year: y, month: m, day: d, location: wdc, config: config)
    }

    private func emptyVoice(
        advance: VoiceLayer? = nil,
        advance2: VoiceLayer? = nil,
        eve: VoiceLayer? = nil,
        morning: VoiceLayer = VoiceLayer(text: "morning", daysBefore: nil),
        offsets: [String: VoiceLayer]? = nil,
        food: FoodNote = FoodNote(note: "", recipeLink: nil)
    ) -> VoiceLayers {
        VoiceLayers(
            advance: advance,
            advance2: advance2,
            eve: eve,
            morning: morning,
            offsets: offsets,
            deepDive: DeepDive(whatItIs: "", mythology: "", history: "", regional: "", whatToDo: ""),
            food: food
        )
    }

    // MARK: - A3: {{masa}} / {{vsYear}} substitution

    @Test func substitutedReplacesMasaTokenWithDisplayedMasaName() {
        // 2026-11-24 at WDC is Kartika Purnima under gujaratiWestern (confirmed against the engine).
        let day = compute(2026, 11, 24)
        #expect(day.displayedMasaName == "Kartika")

        let voice = emptyVoice(eve: VoiceLayer(text: "Purnima tonight. This one is {{masa}} Purnima.", daysBefore: nil))
        let result = resolver.substituted(voice, day: day)
        #expect(result.eve?.text == "Purnima tonight. This one is Kartika Purnima.")
    }

    @Test func substitutedReplacesVsYearTokenWithDisplayedVikramSamvat() {
        // 2026-11-09 at WDC is Bestu Varas (Shukla Pratipada, the day after Diwali) under
        // gujaratiWestern; the Kartikadi Samvat rolls over to 2083 on this day.
        let day = compute(2026, 11, 9)
        #expect(day.displayedVikramSamvat == 2083)

        let voice = emptyVoice(morning: VoiceLayer(text: "A new year begins. Vikram Samvat {{vsYear}} begins now.", daysBefore: nil))
        let result = resolver.substituted(voice, day: day)
        #expect(result.morning.text == "A new year begins. Vikram Samvat 2083 begins now.")
    }

    @Test func substitutedCoversAdvanceAdvance2OffsetsAndFoodNote() {
        let day = compute(2026, 11, 24) // Kartika
        let voice = emptyVoice(
            advance: VoiceLayer(text: "{{masa}} advance.", daysBefore: 3),
            advance2: VoiceLayer(text: "{{masa}} advance2.", daysBefore: 9),
            offsets: ["visarjan": VoiceLayer(text: "Immersion day in {{masa}}.", daysBefore: nil)],
            food: FoodNote(note: "Food note mentions {{masa}}.", recipeLink: nil)
        )
        let result = resolver.substituted(voice, day: day)
        #expect(result.advance?.text == "Kartika advance.")
        #expect(result.advance2?.text == "Kartika advance2.")
        #expect(result.offsets?["visarjan"]?.text == "Immersion day in Kartika.")
        #expect(result.food.note == "Food note mentions Kartika.")
    }

    @Test func substitutedLeavesUnknownBracesAlone() {
        // Not a lint concern here (that's voice-lint's A7) — just confirming the substitution
        // function only touches the two known tokens and doesn't choke on anything else.
        let day = compute(2026, 11, 24)
        let voice = emptyVoice(morning: VoiceLayer(text: "Has {{somethingElse}} untouched.", daysBefore: nil))
        let result = resolver.substituted(voice, day: day)
        #expect(result.morning.text == "Has {{somethingElse}} untouched.")
    }

    // MARK: - A4: the new `paksha` match anchor

    @Test func pakshaAnchorMatchesShuklaDaysOnly() {
        let shuklaDay = compute(2026, 11, 20) // Kartika, Shukla paksha
        #expect(shuklaDay.tithi.paksha == .shukla)
        let krishnaDay = compute(2026, 11, 25) // Kartika, Krishna paksha
        #expect(krishnaDay.tithi.paksha == .krishna)

        let shuklaMatch = ContentMatch(anchor: .paksha, tithi: nil, paksha: .shukla, masaIndex: nil, rashiIndex: nil)
        #expect(resolver.matchesDay(shuklaMatch, day: shuklaDay) == true)
        #expect(resolver.matchesDay(shuklaMatch, day: krishnaDay) == false)

        let krishnaMatch = ContentMatch(anchor: .paksha, tithi: nil, paksha: .krishna, masaIndex: nil, rashiIndex: nil)
        #expect(resolver.matchesDay(krishnaMatch, day: krishnaDay) == true)
        #expect(resolver.matchesDay(krishnaMatch, day: shuklaDay) == false)
    }

    @Test func pakshaAnchorFailsClosedWithoutASinglePaksha() {
        let day = compute(2026, 11, 20)
        let nilPakshaMatch = ContentMatch(anchor: .paksha, tithi: nil, paksha: nil, masaIndex: nil, rashiIndex: nil)
        #expect(resolver.matchesDay(nilPakshaMatch, day: day) == false)
    }

    // MARK: - A1.1: notification body selection

    @Test func bodySelectsAdvance2WhenDaysBeforeMatchesTheTrigger() {
        let voice = emptyVoice(
            advance: VoiceLayer(text: "advance-1", daysBefore: 1),
            advance2: VoiceLayer(text: "advance-2", daysBefore: 3)
        )
        #expect(resolver.body(for: .advance(daysBefore: 3), voice: voice) == "advance-2")
        #expect(resolver.body(for: .advance(daysBefore: 1), voice: voice) == "advance-1")
    }

    @Test func bodyFallsBackToMorningWhenLayerIsMissing() {
        let voice = emptyVoice(morning: VoiceLayer(text: "morning text", daysBefore: nil))
        #expect(resolver.body(for: .advance(daysBefore: 5), voice: voice) == "morning text")
        #expect(resolver.body(for: .eve(time: CodableDateComponents(hour: 20, minute: 0)), voice: voice) == "morning text")
        #expect(resolver.body(for: .dayOffset(9, label: "visarjan", time: nil), voice: voice) == "morning text")
    }

    @Test func bodySelectsOffsetTextByLabel() {
        let voice = emptyVoice(
            morning: VoiceLayer(text: "morning text", daysBefore: nil),
            offsets: [
                "visarjan": VoiceLayer(text: "visarjan text", daysBefore: nil),
                "night5": VoiceLayer(text: "night5 text", daysBefore: nil),
            ]
        )
        #expect(resolver.body(for: .dayOffset(9, label: "visarjan", time: nil), voice: voice) == "visarjan text")
        #expect(resolver.body(for: .dayOffset(4, label: "night5", time: nil), voice: voice) == "night5 text")
        #expect(resolver.body(for: .dayOffset(0, label: "unknownLabel", time: nil), voice: voice) == "morning text")
    }
}
