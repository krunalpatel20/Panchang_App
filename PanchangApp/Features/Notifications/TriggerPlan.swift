import Foundation
import UserNotifications

/// A collection of scheduled triggers ready for delivery to UNUserNotificationCenter.
struct TriggerPlan: Sendable {
    let triggers: [ScheduledTrigger]

    /// De-duplicates by hour bucket: for each (fireDate rounded to hour), keeps the single
    /// trigger with the lowest tier value (highest priority, since tier 1 > tier 5).
    func deduplicated() -> TriggerPlan {
        var bestByHour: [Date: ScheduledTrigger] = [:]
        for trigger in triggers {
            let bucket = trigger.fireDate.roundedToHour(timeZone: trigger.timeZone)
            if let existing = bestByHour[bucket] {
                if trigger.tier < existing.tier {
                    bestByHour[bucket] = trigger
                }
            } else {
                bestByHour[bucket] = trigger
            }
        }
        let deduped = bestByHour.values.sorted { $0.fireDate < $1.fireDate }
        return TriggerPlan(triggers: deduped)
    }

    /// Converts to UNNotificationRequest array — one request per trigger.
    func toNotificationRequests() -> [UNNotificationRequest] {
        triggers.map { trigger in
            let content = UNMutableNotificationContent()
            content.title = trigger.title
            content.body = trigger.body
            content.sound = .default
            content.userInfo = ["entryId": trigger.deepDiveEntryId]

            // Use the trigger's own timezone (the location it was computed for), not the
            // device's current timezone — otherwise a traveling user's notifications fire
            // at the wrong wall-clock time relative to the location they configured.
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = trigger.timeZone
            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: trigger.fireDate)
            comps.timeZone = trigger.timeZone
            let unTrigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            return UNNotificationRequest(
                identifier: trigger.id,
                content: content,
                trigger: unTrigger
            )
        }
    }
}

// MARK: - Helpers

private extension Date {
    func roundedToHour(timeZone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: self)
        return cal.date(from: comps) ?? self
    }
}
