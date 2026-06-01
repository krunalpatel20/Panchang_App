import Foundation
import Observation
import PanchangKit

@Observable
@MainActor
final class TodayViewModel {
    enum LoadState {
        case idle
        case loading
        case loaded(PanchangDay)
        case failed(String)
    }

    var state: LoadState = .idle

    private let service = PanchangService()

    /// Default location used until M4 adds CoreLocation / saved locations.
    /// Defaults to San Jose, CA — the largest Gujarati diaspora city in the app's primary market.
    private var location = GeoLocation(
        latitude: 37.3382,
        longitude: -121.8863,
        timeZoneIdentifier: "America/Los_Angeles"
    )
    private var config = CalendarConfig.gujaratiWestern

    func load() {
        state = .loading
        let loc = location
        let cfg = config
        let svc = service
        Task.detached(priority: .userInitiated) {
            let day = svc.computeToday(location: loc, config: cfg)
            await MainActor.run {
                self.state = .loaded(day)
            }
        }
    }

    func refresh() { load() }
}
