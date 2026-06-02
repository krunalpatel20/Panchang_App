import Foundation
import SwiftData

/// A named geographic location saved by the user.
@Model
final class SavedLocation {
    var name: String
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
    var isActive: Bool
    var createdAt: Date

    init(name: String, latitude: Double, longitude: Double, timeZoneIdentifier: String, isActive: Bool = false) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isActive = isActive
        self.createdAt = Date()
    }
}

/// App-wide preferences.
@Model
final class Preferences {
    var calendarPreset: String   // "gujarati_western" | "north_indian"
    var ayanamsaMode: String     // "lahiri" (others: v2)
    var scriptMode: String       // "transliteration" | "devanagari" | "english"
    var notificationsEnabled: Bool = false

    init() {
        self.calendarPreset = "gujarati_western"
        self.ayanamsaMode = "lahiri"
        self.scriptMode = "transliteration"
    }
}

/// A cached panchang result for a (date, location) pair.
@Model
final class CachedDay {
    /// ISO-8601 date string "YYYY-MM-DD" (civil date in the location's timezone).
    var dateKey: String
    var locationKey: String    // "lat,lon" rounded to 3 decimal places
    var preset: String
    var computedAt: Date
    /// Serialised `PanchangDay` as JSON data.
    var payload: Data

    init(dateKey: String, locationKey: String, preset: String, payload: Data) {
        self.dateKey = dateKey
        self.locationKey = locationKey
        self.preset = preset
        self.computedAt = Date()
        self.payload = payload
    }
}
