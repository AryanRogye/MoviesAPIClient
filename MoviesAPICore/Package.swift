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
    dependencies: [
        .package(
            url: "https://github.com/sindresorhus/Defaults.git",
            from: "9.0.9"
        ),
    ],
    targets: [
        .binaryTarget(
            name: "SharedLogic",
            path: "Frameworks/SharedLogic.xcframework"
        ),
        .target(
            name: "MemoryUsage"
        ),
        .target(
            name: "MoviesAPICore",
            dependencies: [
                "SharedLogic",
                "MemoryUsage",
                .product(name: "Defaults", package: "Defaults"),
            ],
            resources: [
                .process("Features/WebKit/NetworkFiltering/NetworkBlockingRules.json"),
                .copy("Features/WebKit/NetworkFiltering/NetworkBlockingRules.json.license"),
                .process("Features/WebKit/PopupFiltering/PopupFilters.json"),
                .process("Views/Watch/monitorIFrame.js"),
                .process("Views/Watch/IFrameLogger.js")
            ],
            swiftSettings: [
                .defaultIsolation(nil),
            ],
        ),
    ],
    swiftLanguageModes: [.v5],
)
