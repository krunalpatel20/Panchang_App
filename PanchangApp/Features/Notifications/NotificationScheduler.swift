import Foundation
import UserNotifications
import PanchangKit

// MARK: - NoOp stub (replaced at integration time by Track A's real resolver)

struct NoOpContentResolver: ContentResolving {
    func resolve(for day: PanchangDay, region: String?) -> [ResolvedContent] { [] }
    func triggers(forUpcoming days: Int, from start: Date, location: GeoLocation, config: CalendarConfig) -> [ScheduledTrigger] { [] }
}

// MARK: - Scheduler

/// Converts `ContentResolving` output into pending UNNotificationRequests.
/// Keeps at most 60 requests pending (iOS cap is 64; 4 slots reserved for system use).
@MainActor
final class NotificationScheduler: Sendable {
    static let shared = NotificationScheduler()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let maxPending = 60

    /// Schedule upcoming content notifications using the provided resolver.
    /// Removes any previously-scheduled content notifications first so rescheduling is idempotent.
    func schedule(using resolver: ContentResolving, location: GeoLocation, config: CalendarConfig) async {
        await cancelAll()

        let rawTriggers = resolver.triggers(
            forUpcoming: 30,
            from: Date(),
            location: location,
            config: config
        )

        let plan = TriggerPlan(triggers: rawTriggers)
            .deduplicated()

        let capped = TriggerPlan(triggers: Array(plan.triggers.prefix(maxPending)))
        let requests = capped.toNotificationRequests()

        for request in requests {
            try? await center.add(request)
        }
    }

    /// Cancel all pending content notifications (identifiers not prefixed with "festival.").
    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let contentIds = pending
            .map(\.identifier)
            .filter { !$0.hasPrefix("festival.") }
        center.removePendingNotificationRequests(withIdentifiers: contentIds)
    }
}
