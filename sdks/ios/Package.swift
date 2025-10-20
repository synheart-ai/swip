// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "SWIP",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "SWIP",
            targets: ["SWIP"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "SWIP",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Crypto", package: "swift-crypto")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "SWIPTests",
            dependencies: ["SWIP"],
            path: "Tests"
        ),
    ]
)
