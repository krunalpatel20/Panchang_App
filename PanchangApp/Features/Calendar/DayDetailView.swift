import SwiftUI
import SwiftData
import PanchangKit

struct DayDetailView: View {
    let year: Int
    let month: Int
    let day: Int
    let location: GeoLocation
    let config: CalendarConfig

    @Query private var prefsQuery: [Preferences]
    private var scriptMode: String { prefsQuery.first?.scriptMode ?? "transliteration" }

    @State private var state: LoadState = .loading

    private enum LoadState {
        case loading
        case loaded(PanchangDay, [FestivalOccurrence], [ResolvedContent])
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Computing…").frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let day, let festivals, let resolved):
                PanchangDayView(day: day, festivals: festivals,
                                scriptMode: scriptMode, resolvedContent: resolved)
            }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        let loc = location; let cfg = config
        let y = year, m = month, d = day
        let (pDay, festivals) = await Task.detached(priority: .userInitiated) {
            let d = PanchangService().compute(year: y, month: m, day: d, location: loc, config: cfg)
            return (d, FestivalService.shared.festivals(for: d))
        }.value
        let resolved = ContentResolver().resolve(for: pDay, region: prefsQuery.first?.contentRegion)
        state = .loaded(pDay, festivals, resolved)
    }

    private var navTitle: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM yyyy"
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        return fmt.string(from: Calendar.current.date(from: comps) ?? Date())
    }
}
