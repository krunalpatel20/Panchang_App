import Foundation

/// A geographic location with the timezone needed to present timings in local time.
///
/// Longitude follows the **standard** convention: east is positive, west is negative
/// (e.g. San Jose ≈ -121.89). The SwiftAA adapter converts to Meeus' positively-westward
/// convention internally; engine and callers never see that.
public struct GeoLocation: Sendable, Hashable, Codable {
    /// Degrees, north positive. Range -90...90.
    public let latitude: Double
    /// Degrees, **east positive** (standard / GeoJSON convention). Range -180...180.
    public let longitude: Double
    /// IANA timezone identifier used only for local-time display (e.g. "America/Los_Angeles").
    public let timeZoneIdentifier: String

    public init(latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    /// The resolved `TimeZone`, falling back to GMT if the identifier is unknown.
    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(identifier: "GMT")!
    }
}
