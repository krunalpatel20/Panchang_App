import Foundation
import PanchangKit

/// Thin app-facing facade over PanchangKit. Adds date-decomposition helpers that the UI
/// needs but the pure engine does not (e.g. "today in this timezone"). All heavy work is
/// done on a background Task to keep the main actor free. Results are cached to SwiftData
/// by TodayViewModel.
struct PanchangService: Sendable {
    private let panchang = Panchang()

    func compute(date: Date, location: GeoLocation, config: CalendarConfig) -> PanchangDay {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return panchang.compute(year: c.year!, month: c.month!, day: c.day!, location: location, config: config)
    }

    func computeToday(location: GeoLocation, config: CalendarConfig) -> PanchangDay {
        compute(date: Date(), location: location, config: config)
    }
}
