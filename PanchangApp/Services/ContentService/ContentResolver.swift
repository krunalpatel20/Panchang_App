import Foundation
import PanchangKit

/// Implements `ContentResolving`: matches `ContentEntry` values from `ContentStore` against
/// a `PanchangDay`, applies variant inheritance, and expands triggers into `ScheduledTrigger`s.
struct ContentResolver: ContentResolving {

    // MARK: - ContentResolving

    func resolve(for day: PanchangDay, region: String?) -> [ResolvedContent] {
        var results: [ResolvedContent] = []

        for entry in ContentStore.shared.allEntries {
            // Region filter: empty regions means everywhere
            if !entry.regions.isEmpty, let region {
                guard entry.regions.contains(region) else { continue }
            } else if !entry.regions.isEmpty && region == nil {
                // No region provided but entry is region-restricted — skip
                continue
            }

            guard matchesDay(entry.match, day: day) else { continue }

            // Variant inheritance: find the most-specific variant that also matches
            let (voice, triggers, action) = applyVariant(for: entry, day: day)

            let date = gregorianDate(from: day)
            results.append(ResolvedContent(
                entry: entry,
                voice: substituted(voice, day: day),
                triggers: triggers,
                action: action,
                date: date
            ))
        }

        // Sort by tier ascending (tier 1 = highest priority first)
        return results.sorted { $0.entry.tier < $1.entry.tier }
    }

    func triggers(
        forUpcoming days: Int,
        from start: Date,
        location: GeoLocation,
        config: CalendarConfig,
        region: String?
    ) -> [ScheduledTrigger] {
        let service = PanchangService()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone

        var allTriggers: [ScheduledTrigger] = []

        for offset in 0 ..< days {
            guard let date = cal.date(byAdding: .day, value: offset, to: start) else { continue }
            let day = service.compute(date: date, location: location, config: config)
            let resolved = resolve(for: day, region: region)

            let isoDate = isoDateString(from: date, timeZone: location.timeZone)

            for rc in resolved {
                for trigger in rc.triggers {
                    guard let (fireDate, kindKey) = fireDate(
                        for: trigger,
                        dayDate: date,
                        timeZone: location.timeZone,
                        calendar: cal
                    ) else { continue }

                    let id = "content.\(rc.entry.id)-\(kindKey)-\(isoDate)"

                    allTriggers.append(ScheduledTrigger(
                        id: id,
                        title: rc.entry.name,
                        body: body(for: trigger, voice: rc.voice),
                        fireDate: fireDate,
                        timeZone: location.timeZone,
                        tier: rc.entry.tier,
                        deepDiveEntryId: rc.entry.id
                    ))
                }
            }
        }

        // Same-hour collisions (e.g. Ekadashi + Pradosh both firing at 8am) are resolved by
        // TriggerPlan.deduplicated(), which keeps the lowest-tier (highest-priority) trigger.
        return allTriggers.sorted { $0.fireDate < $1.fireDate }
    }

    // MARK: - Matching

    /// Not `private`: exercised directly by unit tests (e.g. the `.paksha` anchor, which has
    /// no dedicated content entries yet to resolve through the public API).
    func matchesDay(_ match: ContentMatch, day: PanchangDay) -> Bool {
        switch match.anchor {
        case .tithi:
            return tithiMatches(match: match, day: day)

        case .masaTithi:
            // Fail closed: a masaTithi entry without a tithi would otherwise match every day
            // of that masa (~30 days). Entries that want "the whole month" should use a
            // dedicated anchor (e.g. solar) rather than relying on this gap.
            guard match.tithi != nil else { return false }
            guard tithiMatches(match: match, day: day) else { return false }
            if let masaIndex = match.masaIndex {
                guard day.masa.amantaIndex == masaIndex else { return false }
            }
            return true

        case .pakshaTransition:
            // match.paksha describes the paksha that just ENDED (the convention the variants
            // use): "shukla" → today is Krishna Pratipada (index 15); "krishna" → today is
            // Shukla Pratipada (index 0). The base entry (paksha nil) matches either transition.
            switch match.paksha {
            case .shukla: return day.tithi.index == 15
            case .krishna: return day.tithi.index == 0
            case .both, nil: return day.tithi.index == 0 || day.tithi.index == 15
            }

        case .solar:
            guard let rashi = match.rashiIndex else { return false }
            return day.isSolarTransition && day.sunRashiIndex == rashi

        case .paksha:
            // Fail closed like masaTithi: nil (and .both, which doesn't identify a single
            // paksha) must not match every day.
            return match.paksha.map { day.tithi.paksha == ($0 == .shukla ? .shukla : .krishna) } ?? false
        }
    }

    /// Returns true if the match's tithi/paksha conditions are met.
    /// `match.tithi` is 1-based (1=Pratipada … 15=Purnima/Amavasya) per paksha, matching
    /// FestivalEngine's convention.
    private func tithiMatches(match: ContentMatch, day: PanchangDay) -> Bool {
        guard let tithiNum = match.tithi else { return true }

        let pakshaFilter = match.paksha

        switch pakshaFilter {
        case .shukla, nil:
            let expectedIndex = tithiNum - 1          // Shukla 1 → 0 … Shukla 15 → 14
            if pakshaFilter == nil {
                // nil paksha means match either paksha at position tithiNum
                let krishnaIndex = 15 + (tithiNum - 1)
                return day.tithi.index == expectedIndex || day.tithi.index == krishnaIndex
            }
            return day.tithi.index == expectedIndex && day.tithi.paksha == .shukla

        case .krishna:
            let expectedIndex = 15 + (tithiNum - 1)  // Krishna 1 → 15 … Krishna 15 → 29
            return day.tithi.index == expectedIndex && day.tithi.paksha == .krishna

        case .both:
            let shuklaIdx = tithiNum - 1
            let krishnaIdx = 15 + (tithiNum - 1)
            return day.tithi.index == shuklaIdx || day.tithi.index == krishnaIdx
        }
    }

    // MARK: - Variant inheritance

    /// Returns the voice/triggers/action to use, after applying the most-specific matching variant.
    private func applyVariant(for entry: ContentEntry, day: PanchangDay) -> (VoiceLayers, [NotificationTrigger], ContentAction?) {
        let candidates = entry.variants.filter { matchesDay($0.match, day: day) }

        // More-specific = more non-nil fields in the match
        let best = candidates.max(by: { specificity($0.match) < specificity($1.match) })

        var voice = best?.voice ?? entry.voice
        // morningOverride swaps only the morning layer; everything else inherits from base.
        if let morningOverride = best?.morningOverride {
            voice = VoiceLayers(
                advance: voice.advance,
                advance2: voice.advance2,
                eve: voice.eve,
                morning: morningOverride,
                offsets: voice.offsets,
                deepDive: voice.deepDive,
                food: voice.food
            )
        }
        let triggers = best?.triggers ?? entry.triggers
        let action = best?.action ?? entry.action

        return (voice, triggers, action)
    }

    // MARK: - Notification body selection

    /// Picks the voice text for a fired trigger. Not `private`: exercised directly by unit
    /// tests covering the advance/advance2/eve/dayOffset selection rules (A1.1).
    func body(for trigger: NotificationTrigger, voice: VoiceLayers) -> String {
        switch trigger {
        case .advance(let d):
            if let a2 = voice.advance2, a2.daysBefore == d { return a2.text }
            return voice.advance?.text ?? voice.morning.text
        case .eve:
            return voice.eve?.text ?? voice.morning.text
        case .dayOffset(_, let label, _):
            return voice.offsets?[label]?.text ?? voice.morning.text
        case .morning, .midnight:
            return voice.morning.text
        }
    }

    // MARK: - Template token substitution

    /// Substitutes `{{masa}}`/`{{vsYear}}` tokens across every text field of a resolved
    /// `VoiceLayers`. Not `private`: exercised directly by unit tests so token substitution
    /// can be verified without depending on content authoring landing first (A3).
    func substituted(_ voice: VoiceLayers, day: PanchangDay) -> VoiceLayers {
        func sub(_ s: String) -> String {
            s.replacingOccurrences(of: "{{masa}}", with: day.displayedMasaName)
             .replacingOccurrences(of: "{{vsYear}}", with: String(day.displayedVikramSamvat))
        }
        func sub(_ layer: VoiceLayer?) -> VoiceLayer? {
            guard let layer else { return nil }
            return VoiceLayer(text: sub(layer.text), daysBefore: layer.daysBefore)
        }

        let deepDive = voice.deepDive
        let subbedDeepDive = DeepDive(
            whatItIs: sub(deepDive.whatItIs),
            mythology: sub(deepDive.mythology),
            history: sub(deepDive.history),
            regional: sub(deepDive.regional),
            whatToDo: sub(deepDive.whatToDo)
        )

        let subbedOffsets = voice.offsets?.mapValues { layer in
            VoiceLayer(text: sub(layer.text), daysBefore: layer.daysBefore)
        }

        return VoiceLayers(
            advance: sub(voice.advance),
            advance2: sub(voice.advance2),
            eve: sub(voice.eve),
            morning: VoiceLayer(text: sub(voice.morning.text), daysBefore: voice.morning.daysBefore),
            offsets: subbedOffsets,
            deepDive: subbedDeepDive,
            food: FoodNote(note: sub(voice.food.note), recipeLink: voice.food.recipeLink)
        )
    }

    private func specificity(_ match: ContentMatch) -> Int {
        var score = 0
        if match.tithi != nil { score += 1 }
        if match.paksha != nil { score += 1 }
        if match.masaIndex != nil { score += 1 }
        if match.rashiIndex != nil { score += 1 }
        return score
    }

    // MARK: - Date helpers

    private func gregorianDate(from day: PanchangDay) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = day.location.timeZone
        return cal.date(from: DateComponents(
            year: day.year,
            month: day.month,
            day: day.day
        )) ?? Date()
    }

    private func isoDateString(from date: Date, timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Trigger fire-date calculation

    /// Returns (fireDate, kindKey) for a trigger relative to a matched day, or nil if unsupported.
    private func fireDate(
        for trigger: NotificationTrigger,
        dayDate: Date,
        timeZone: TimeZone,
        calendar: Calendar
    ) -> (Date, String)? {
        let cal = calendar

        switch trigger {
        case .advance(let daysBefore):
            guard let advanceDate = cal.date(byAdding: .day, value: -daysBefore, to: dayDate) else { return nil }
            let fireDate = dateAtHourMinute(date: advanceDate, hour: 8, minute: 0, timeZone: timeZone)
            return (fireDate, "advance\(daysBefore)")

        case .eve(let time):
            guard let eveDate = cal.date(byAdding: .day, value: -1, to: dayDate) else { return nil }
            let fireDate = dateAtHourMinute(date: eveDate, hour: time.hour, minute: time.minute, timeZone: timeZone)
            return (fireDate, "eve")

        case .morning(let time):
            let fireDate = dateAtHourMinute(date: dayDate, hour: time.hour, minute: time.minute, timeZone: timeZone)
            return (fireDate, "morning")

        case .midnight:
            let fireDate = dateAtHourMinute(date: dayDate, hour: 0, minute: 0, timeZone: timeZone)
            return (fireDate, "midnight")

        case .dayOffset(let offset, let label, let time):
            guard let offsetDate = cal.date(byAdding: .day, value: offset, to: dayDate) else { return nil }
            let fireDate = dateAtHourMinute(date: offsetDate, hour: time?.hour ?? 8, minute: time?.minute ?? 0, timeZone: timeZone)
            return (fireDate, "offset-\(label)")
        }
    }

    private func dateAtHourMinute(date: Date, hour: Int, minute: Int, timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        var c = cal.dateComponents([.year, .month, .day], from: date)
        c.hour = hour
        c.minute = minute
        c.second = 0
        return cal.date(from: c) ?? date
    }
}
