import Foundation
import Observation
import PanchangKit

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
    private let service = PanchangService()
    /// Bumped on each load so a slow earlier compute can't overwrite a newer one.
    private var generation = 0

    func load(location: GeoLocation, config: CalendarConfig) {
        state = .loading
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
        }
    }

    func refresh(location: GeoLocation, config: CalendarConfig) { load(location: location, config: config) }
}
