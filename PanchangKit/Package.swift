// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PanchangKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PanchangKit", targets: ["PanchangKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/onekiloparsec/SwiftAA", from: "2.4.0"),
    ],
    targets: [
        .target(
            name: "PanchangKit",
            dependencies: [
                .product(name: "SwiftAA", package: "SwiftAA"),
            ]
        ),
        .testTarget(
            name: "PanchangKitTests",
            dependencies: ["PanchangKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
