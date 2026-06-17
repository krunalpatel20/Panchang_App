import Foundation
import UserNotifications
import PanchangKit

/// Converts `ContentResolving` output into pending UNNotificationRequests.
/// Keeps at most 60 requests pending (iOS cap is 64; 4 slots reserved for system use).
///
/// Not main-actor-bound: `schedule(using:)` resolves up to 30 days of panchang content,
/// which means up to 30 synchronous `PanchangService.compute()` calls — expensive enough
/// that running it on the main actor would freeze the UI at launch. `UNUserNotificationCenter`
/// is documented thread-safe, so this is safe to call from any execution context.
final class NotificationScheduler: @unchecked Sendable {
    static let shared = NotificationScheduler()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let maxPending = 60

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Schedule upcoming content notifications using the provided resolver.
    /// Removes any previously-scheduled content notifications first so rescheduling is idempotent.
    func schedule(
        using resolver: ContentResolving,
        location: GeoLocation,
        config: CalendarConfig,
        region: String?
    ) async {
        await cancelAll()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let rawTriggers = resolver.triggers(
            forUpcoming: 30,
            from: Date(),
            location: location,
            config: config,
            region: region
        )

        let plan = TriggerPlan(triggers: rawTriggers)
            .deduplicated()

        let capped = TriggerPlan(triggers: Array(plan.triggers.prefix(maxPending)))
        let requests = capped.toNotificationRequests()

        for request in requests {
            try? await center.add(request)
        }
    }

    /// Cancel all pending content notifications. Scoped to the "content." id prefix so this
    /// doesn't sweep up notifications some other feature schedules in the future.
    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let contentIds = pending.map(\.identifier).filter { $0.hasPrefix("content.") }
        center.removePendingNotificationRequests(withIdentifiers: contentIds)
    }
}
