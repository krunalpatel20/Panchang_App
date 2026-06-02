import Foundation
import UserNotifications
import PanchangKit

/// Schedules local notifications for upcoming festivals/vrats.
/// Requests permission on first call. All scheduling is idempotent — call it
/// whenever the active location or preferences change.
@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let festivalService = FestivalService.shared
    private let panchang = Panchang()

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Scheduling

    /// Schedules festival notifications for the next `daysAhead` days from today.
    func scheduleUpcomingFestivals(location: GeoLocation, config: CalendarConfig, daysAhead: Int = 30) async {
        // Remove previous festival notifications before rescheduling
        let existingIds = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("festival.") }
        center.removePendingNotificationRequests(withIdentifiers: existingIds)

        let settings = await center.notificationSettings()
        let granted = settings.authorizationStatus == .authorized
        guard granted else { return }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let today = Date()

        for offset in 0..<daysAhead {
            guard let date = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let comps = cal.dateComponents([.year, .month, .day], from: date)
            guard let y = comps.year, let m = comps.month, let d = comps.day else { continue }

            let day = panchang.compute(year: y, month: m, day: d, location: location, config: config)
            let festivals = festivalService.festivals(for: day)
            guard !festivals.isEmpty else { continue }

            for festival in festivals {
                let id = "festival.\(y)-\(m)-\(d).\(festival.id)"
                schedule(id: id, festival: festival, on: date, location: location)
            }
        }
    }

    // MARK: - Private

    private func schedule(id: String, festival: FestivalOccurrence, on date: Date, location: GeoLocation) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone

        // Notify at 7:00 AM on the festival day
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 7
        comps.minute = 0

        let content = UNMutableNotificationContent()
        content.title = festival.name
        content.body = "Today is \(festival.name). Tap to view today's panchang."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { _ in }
    }
}
