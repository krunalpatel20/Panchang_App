import Testing
@testable import PanchangKit

// Scaffold smoke test — verifies the package builds and links.
// Golden-vector tests are added in M1.
@Test func packageLoads() {
    #expect(PanchangKit.version == "0.1.0")
}
