import Foundation
import Observation
import PanchangKit

/// A future observance for the home screen's "Coming up" list.
struct UpcomingObservance: Identifiable, Sendable {
    let id: String
    let name: String
    let tagline: String?
    let daysAway: Int
}

@Observable
@MainActor
final class TodayViewModel {
    enum LoadState {
        case idle
        case loading
        case loaded(PanchangDay, [FestivalOccurrence])
        case failed(String)
    }

    var state: LoadState = .idle
    /// Filled in a second pass after `state` becomes `.loaded` — scanning ahead is slower
    /// than computing today, and the hero content shouldn't wait for it.
    var upcoming: [UpcomingObservance] = []

    private let service = PanchangService()
    /// Bumped on each load so a slow earlier compute can't overwrite a newer one.
    private var generation = 0

    /// How far ahead the "Coming up" scan looks. Tier 1-2 observances recur at least
    /// monthly (Ekadashi, Purnima, Amavasya), so 60 days always yields three items.
    private nonisolated static let scanDays = 60
    private nonisolated static let upcomingCount = 3

    /// `includeUpcoming` runs the 60-day "Coming up" scan after today loads — only the
    /// home screen needs it; MuhurtaView shares this view model and skips the cost.
    func load(location: GeoLocation, config: CalendarConfig,
              region: String? = nil, includeUpcoming: Bool = false) {
        state = .loading
        upcoming = []
        generation += 1
        let gen = generation
        let loc = location; let cfg = config; let svc = service
        Task.detached(priority: .userInitiated) {
            let day = svc.computeToday(location: loc, config: cfg)
            let festivals = FestivalService.shared.festivals(for: day)
            await MainActor.run {
                guard gen == self.generation else { return }
                self.state = .loaded(day, festivals)
            }
            guard includeUpcoming else { return }

            let items = Self.scanUpcoming(after: day, location: loc, config: cfg,
                                          region: region, service: svc)
            await MainActor.run {
                guard gen == self.generation else { return }
                self.upcoming = items
            }
        }
    }

    func refresh(location: GeoLocation, config: CalendarConfig,
                 region: String? = nil, includeUpcoming: Bool = false) {
        load(location: location, config: config, region: region, includeUpcoming: includeUpcoming)
    }

    private nonisolated static func scanUpcoming(
        after today: PanchangDay,
        location: GeoLocation,
        config: CalendarConfig,
        region: String?,
        service: PanchangService
    ) -> [UpcomingObservance] {
        let resolver = ContentResolver()
        // Entries already matched today are the hero, not "coming up".
        let todayIds = Set(resolver.resolve(for: today, region: region).map(\.entry.id))

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let start = Date()

        var found: [UpcomingObservance] = []
        for offset in 1 ... scanDays {
            guard found.count < upcomingCount,
                  let date = cal.date(byAdding: .day, value: offset, to: start) else { break }
            let day = service.compute(date: date, location: location, config: config)
            // Take only the top match per day: a specific festival (Guru Purnima)
            // outranks the generic cycle entry (Purnima) falling on the same tithi.
            guard let rc = resolver.resolve(for: day, region: region).first(where: {
                $0.entry.tier <= 2 && $0.entry.festivalType != nil
            }) else { continue }
            guard !todayIds.contains(rc.entry.id),
                  !found.contains(where: { $0.id == rc.entry.id }) else { continue }
            found.append(UpcomingObservance(id: rc.entry.id,
                                            name: rc.entry.name,
                                            tagline: rc.entry.tagline,
                                            daysAway: offset))
        }
        return Array(found.prefix(upcomingCount))
    }
}
