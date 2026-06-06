import Foundation

/// Sidereal positions of the nine grahas plus the ascendant (lagna) at an instant.
/// All longitudes are **sidereal** (Lahiri by default): `tropical − ayanamsa(jd)`.
public struct PlanetaryPositions: Sendable {
    public struct Planet: Sendable, Identifiable {
        public let id: String          // "sun", "moon", …, "rahu", "ketu", "lagna"
        public let name: String
        public let longitude: Double   // sidereal ecliptic longitude, [0, 360)
        public let rashi: Int          // 0…11 (Aries…Pisces)
        public let rashiName: String
        public let nakshatra: Int      // 0…26
        public let navamshaRashi: Int  // 0…11 (D9 sign)
        public let isRetrograde: Bool

        public init(id: String, name: String, longitude: Double,
                    nakshatra: Int? = nil, isRetrograde: Bool) {
            let lon = AngleMath.normalize360(longitude)
            self.id = id
            self.name = name
            self.longitude = lon
            self.rashi = min(11, Int(floor(lon / 30.0)))
            self.rashiName = PanchangNames.rashi[min(11, Int(floor(lon / 30.0)))]
            self.nakshatra = nakshatra ?? min(26, Int(floor(lon / (360.0 / 27.0))))
            self.navamshaRashi = Navamsha.rashi(siderealLongitude: lon)
            self.isRetrograde = isRetrograde
        }
    }

    public let planets: [Planet]   // 9 grahas: Sun, Moon, Mars, Mercury, Jupiter, Venus, Saturn, Rahu, Ketu
    public let lagna: Planet       // ascendant
    public let julianDay: Double

    /// Convenience: the Moon's sidereal longitude, used to seed Vimshottari dasha.
    public var moonLongitude: Double { planets[1].longitude }
}

/// Computes sidereal planetary positions from an injected ephemeris + ayanamsa.
struct PlanetaryCalculator {
    let ephemeris: Ephemeris
    let ayanamsa: Ayanamsa

    /// A retrograde sampling step. Half a day is short enough that the ayanamsa drift is
    /// negligible yet long enough to resolve direction of motion away from stationary points.
    private static let retroStep = 0.5

    private func sidereal(_ tropical: Double, _ jd: Double) -> Double {
        AngleMath.normalize360(tropical - ayanamsa.value(julianDay: jd))
    }

    /// True when the body's sidereal longitude is decreasing at `jd` (apparent retrograde
    /// motion). Frame-independent — the ayanamsa drift over the sampling step is ~6e-5°.
    private func isRetrograde(_ graha: Graha, _ jd: Double) -> Bool {
        // Sun and Moon never retrograde; skip the sampling.
        if graha == .sun || graha == .moon { return false }
        let a = ephemeris.longitude(of: graha, julianDay: jd)
        let b = ephemeris.longitude(of: graha, julianDay: jd + Self.retroStep)
        return AngleMath.normalize180(b - a) < 0
    }

    func positions(julianDay jd: Double, lagnaLongitude: Double) -> PlanetaryPositions {
        var planets: [PlanetaryPositions.Planet] = []

        for (i, graha) in Graha.allCases.enumerated() {
            let lon = sidereal(ephemeris.longitude(of: graha, julianDay: jd), jd)
            planets.append(PlanetaryPositions.Planet(
                id: graha.rawValue,
                name: PanchangNames.graha[i],
                longitude: lon,
                isRetrograde: isRetrograde(graha, jd)
            ))
        }

        // Rahu (mean ascending node) and Ketu (descending node, +180°). Both always retrograde.
        let rahu = sidereal(ephemeris.lunarNodeLongitude(julianDay: jd), jd)
        let ketu = AngleMath.normalize360(rahu + 180.0)
        planets.append(PlanetaryPositions.Planet(id: "rahu", name: "Rahu", longitude: rahu, isRetrograde: true))
        planets.append(PlanetaryPositions.Planet(id: "ketu", name: "Ketu", longitude: ketu, isRetrograde: true))

        let lagna = PlanetaryPositions.Planet(
            id: "lagna", name: "Lagna",
            longitude: AngleMath.normalize360(lagnaLongitude),
            isRetrograde: false
        )

        return PlanetaryPositions(planets: planets, lagna: lagna, julianDay: jd)
    }
}
