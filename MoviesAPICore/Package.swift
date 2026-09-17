// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MoviesAPICore",
    platforms: [
        .iOS(.v27),
        .macOS(.v27),
    ],
    products: [
        .library(
            name: "MoviesAPICore",
            targets: ["MoviesAPICore"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "SharedLogic",
            path: "Frameworks/SharedLogic.xcframework"
        ),
        .target(
            name: "MoviesAPICore",
            dependencies: ["SharedLogic"],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),

    ]
)
