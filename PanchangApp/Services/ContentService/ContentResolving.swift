import Foundation
import PanchangKit

// MARK: - Resolved types

/// A content entry matched to a specific day, with variant inheritance applied.
struct ResolvedContent: Sendable, Identifiable {
    var id: String { "\(entry.id)-\(date.timeIntervalSince1970)" }
    let entry: ContentEntry
    let voice: VoiceLayers
    let triggers: [NotificationTrigger]
    let action: ContentAction?
    let date: Date
}

/// A notification ready to schedule, derived from a trigger + resolved content.
struct ScheduledTrigger: Sendable {
    let id: String // stable: "\(entryId)-\(kind)-\(isoDate)"
    let title: String
    let body: String
    let fireDate: Date
    /// The timezone `fireDate`'s wall-clock components were computed in — needed so
    /// `UNCalendarNotificationTrigger` fires at the intended local time even when the
    /// device's current timezone differs from the location the panchang was computed for.
    let timeZone: TimeZone
    let tier: Int
    let deepDiveEntryId: String
}

// MARK: - Protocol

/// The seam between the clock (PanchangKit) and the voice (ContentService).
/// Track A implements this. All other tracks mock against it.
protocol ContentResolving: Sendable {
    /// Returns all content entries that match `day`, with most-specific variant applied.
    func resolve(for day: PanchangDay, region: String?) -> [ResolvedContent]

    /// Returns all scheduled notification triggers for the next `days` days.
    func triggers(
        forUpcoming days: Int,
        from start: Date,
        location: GeoLocation,
        config: CalendarConfig,
        region: String?
    ) -> [ScheduledTrigger]
}
