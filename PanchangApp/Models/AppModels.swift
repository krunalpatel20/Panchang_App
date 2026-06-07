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
    /// Janma (birth) nakshatra 0…26 for Tara Bala; -1 = not set.
    var janmaNakshatra: Int = -1
    /// Janma (birth) rashi 0…11 for Chandra Bala; -1 = not set.
    var janmaRashi: Int = -1
    /// Kundli chakra style: "north" (square diamond) | "south" (fixed grid).
    var kundliStyle: String = "north"

    init() {
        self.calendarPreset = "gujarati_western"
        self.ayanamsaMode = "lahiri"
        self.scriptMode = "transliteration"
    }
}

/// A saved birth profile (self + family) for kundli and dasha. The birth instant is stored as
/// an absolute `Date`; the timezone is kept separately for display and re-derivation.
@Model
final class BirthProfile {
    var name: String
    var birthInstant: Date
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
    var placeName: String
    var isPrimary: Bool
    var createdAt: Date

    init(name: String, birthInstant: Date, latitude: Double, longitude: Double,
         timeZoneIdentifier: String, placeName: String, isPrimary: Bool = false) {
        self.name = name
        self.birthInstant = birthInstant
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
        self.placeName = placeName
        self.isPrimary = isPrimary
        self.createdAt = Date()
    }
}
