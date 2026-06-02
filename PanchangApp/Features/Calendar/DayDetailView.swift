import SwiftUI
import PanchangKit

struct DayDetailView: View {
    let year: Int
    let month: Int
    let day: Int
    let location: GeoLocation
    let config: CalendarConfig

    @State private var state: LoadState = .loading

    private enum LoadState {
        case loading
        case loaded(PanchangDay, [FestivalOccurrence])
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Computing…").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let day, let festivals):
                PanchangDayView(day: day, festivals: festivals)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        let loc = location; let cfg = config
        let y = year, m = month, d = day
        let result = await Task.detached(priority: .userInitiated) {
            let day = Panchang().compute(year: y, month: m, day: d, location: loc, config: cfg)
            let festivals = FestivalService.shared.festivals(for: day)
            return (day, festivals)
        }.value
        state = .loaded(result.0, result.1)
    }

    private var navTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM yyyy"
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return fmt.string(from: Calendar.current.date(from: comps) ?? Date())
    }
}
