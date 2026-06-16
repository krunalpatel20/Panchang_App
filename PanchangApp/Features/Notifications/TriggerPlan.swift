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
            let bucket = trigger.fireDate.roundedToHour()
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
            content.title = trigger.deepDiveEntryId.humanised
            content.body = trigger.body
            content.sound = .default
            content.userInfo = ["entryId": trigger.deepDiveEntryId]

            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone.current
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: trigger.fireDate)
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
    func roundedToHour() -> Date {
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour], from: self)
        return cal.date(from: comps) ?? self
    }
}

private extension String {
    /// Simple humanisation: replace hyphens/underscores with spaces and capitalise each word.
    /// e.g. "ekadashi" → "Ekadashi", "rama-navami" → "Rama Navami"
    var humanised: String {
        self
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
