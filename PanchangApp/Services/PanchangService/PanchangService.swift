import Foundation
import PanchangKit

/// Thin app-facing facade over PanchangKit. Adds date-decomposition helpers the UI needs but the
/// pure engine does not (e.g. "today in this timezone"), and an in-memory result cache so the same
/// civil day isn't recomputed when the user pages the calendar back and forth or the Today and
/// Calendar tabs overlap. Heavy work is done on a background Task by the callers.
struct PanchangService: Sendable {
    private let panchang = Panchang()

    /// Compute (or fetch from cache) the panchang for a civil date in `location.timeZone`.
    func compute(year: Int, month: Int, day: Int, location: GeoLocation, config: CalendarConfig) -> PanchangDay {
        let key = Self.cacheKey(year: year, month: month, day: day, location: location, config: config)
        if let cached = PanchangDayCache.shared.value(for: key) { return cached }
        let day = panchang.compute(year: year, month: month, day: day, location: location, config: config)
        PanchangDayCache.shared.set(day, for: key)
        return day
    }

    func compute(date: Date, location: GeoLocation, config: CalendarConfig) -> PanchangDay {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return compute(year: c.year!, month: c.month!, day: c.day!, location: location, config: config)
    }

    func computeToday(location: GeoLocation, config: CalendarConfig) -> PanchangDay {
        compute(date: Date(), location: location, config: config)
    }

    private static func cacheKey(year: Int, month: Int, day: Int, location: GeoLocation, config: CalendarConfig) -> String {
        let loc = String(format: "%.3f,%.3f", location.latitude, location.longitude)
        let cfg = "\(config.monthEnd.rawValue)-\(config.yearAnchor.rawValue)"
        return "\(cfg)|\(loc)|\(String(format: "%04d-%02d-%02d", year, month, day))"
    }
}

/// Process-wide, bounded, thread-safe cache of computed `PanchangDay`s keyed by (preset, location,
/// date). Replaces the never-wired `CachedDay` SwiftData model: an in-memory cache is enough for the
/// access pattern (re-paging the calendar, Today/Calendar overlap within a session) and avoids a
/// persistent schema we don't need. FIFO eviction keeps long sessions bounded.
final class PanchangDayCache: @unchecked Sendable {
    static let shared = PanchangDayCache()

    private let lock = NSLock()
    private var store: [String: PanchangDay] = [:]
    private var order: [String] = []
    private let capacity = 400

    private init() {}

    func value(for key: String) -> PanchangDay? {
        lock.lock(); defer { lock.unlock() }
        return store[key]
    }

    func set(_ day: PanchangDay, for key: String) {
        lock.lock(); defer { lock.unlock() }
        if store[key] == nil {
            order.append(key)
            if order.count > capacity {
                store.removeValue(forKey: order.removeFirst())
            }
        }
        store[key] = day
    }
}
