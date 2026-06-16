import Foundation
import Observation
import PanchangKit

/// Minimal festival info carried in each calendar cell.
struct FestivalItem: Sendable, Hashable {
    let name: String
    let type: FestivalRule.FestivalType
}

/// A lightweight summary computed for each calendar grid cell.
struct MonthCell: Sendable, Identifiable, Hashable {
    let id: String           // "YYYY-MM-DD"
    let year: Int
    let month: Int
    let day: Int
    let isCurrentMonth: Bool
    let isToday: Bool
    let tithiName: String
    let paksha: Paksha
    let tithiIndex: Int      // 0…29 raw index
    let sunriseJD: Double?
    let festivals: [FestivalItem]

    var hasFestival: Bool { !festivals.isEmpty }
    var festivalNames: [String] { festivals.map(\.name) }
    /// Type of the highest-priority festival on this day (first as returned by engine).
    var topFestivalType: FestivalRule.FestivalType? { festivals.first?.type }
}

@Observable
@MainActor
final class CalendarViewModel {
    var displayedYear: Int
    var displayedMonth: Int

    var selectedDate: (year: Int, month: Int, day: Int)? = nil
    var cells: [MonthCell] = []
    var isLoading = false
    var showDatePicker = false
    var pickerDate: Date = Date()

    private let service = PanchangService()
    /// Bumped on each load so rapid month paging can't let an earlier month's compute land last.
    private var generation = 0

    init() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let now = cal.dateComponents([.year, .month], from: Date())
        displayedYear = now.year!
        displayedMonth = now.month!
    }

    func goToPreviousMonth(location: GeoLocation, config: CalendarConfig) {
        var m = displayedMonth - 1
        var y = displayedYear
        if m < 1 { m = 12; y -= 1 }
        displayedYear = y; displayedMonth = m
        loadCells(location: location, config: config)
    }

    func goToNextMonth(location: GeoLocation, config: CalendarConfig) {
        var m = displayedMonth + 1
        var y = displayedYear
        if m > 12 { m = 1; y += 1 }
        displayedYear = y; displayedMonth = m
        loadCells(location: location, config: config)
    }

    func jumpTo(date: Date, location: GeoLocation, config: CalendarConfig) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let c = cal.dateComponents([.year, .month], from: date)
        displayedYear = c.year!; displayedMonth = c.month!
        loadCells(location: location, config: config)
    }

    func loadCells(location: GeoLocation, config: CalendarConfig) {
        isLoading = true
        generation += 1
        let gen = generation
        let year = displayedYear
        let month = displayedMonth
        let loc = location
        let cfg = config

        Task.detached(priority: .userInitiated) {
            let cells = Self.buildCells(year: year, month: month, location: loc, config: cfg)
            await MainActor.run {
                guard gen == self.generation else { return }
                self.cells = cells
                self.isLoading = false
            }
        }
    }

    private nonisolated static func buildCells(
        year: Int, month: Int,
        location: GeoLocation, config: CalendarConfig
    ) -> [MonthCell] {
        var gregCal = Calendar(identifier: .gregorian)
        gregCal.timeZone = location.timeZone

        var components = DateComponents()
        components.year = year; components.month = month; components.day = 1
        guard let firstDay = gregCal.date(from: components),
              let range = gregCal.range(of: .day, in: .month, for: firstDay) else { return [] }

        let service = PanchangService()
        let festEngine = FestivalEngine()
        let rules = FestivalService.shared.rules

        let todayComponents = gregCal.dateComponents([.year, .month, .day], from: Date())

        return range.map { d in
            let day = service.compute(year: year, month: month, day: d, location: location, config: config)
            let occurrences = festEngine.festivals(for: day, rules: rules)
            let isToday = todayComponents.year == year && todayComponents.month == month && todayComponents.day == d
            return MonthCell(
                id: String(format: "%04d-%02d-%02d", year, month, d),
                year: year, month: month, day: d,
                isCurrentMonth: true,
                isToday: isToday,
                tithiName: day.tithi.name,
                paksha: day.tithi.paksha,
                tithiIndex: day.tithi.index,
                sunriseJD: day.timings.sunrise,
                festivals: occurrences.map { FestivalItem(name: $0.name, type: $0.type) }
            )
        }
    }
}
