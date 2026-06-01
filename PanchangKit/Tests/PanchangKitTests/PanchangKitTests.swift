import Testing
@testable import PanchangKit

// Scaffold smoke test — verifies the package builds and links.
@Test func packageLoads() {
    let ay = LahiriAyanamsa().value(julianDay: 2451545.0) // J2000
    #expect(ay > 23.0 && ay < 24.5)
}
