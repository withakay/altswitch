// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacWindowSwitch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Core library - zero external dependencies
        .library(
            name: "MacWindowSwitch",
            targets: ["MacWindowSwitch"]
        ),
        // CLI demo tool
        .executable(
            name: "mac-window-switch",
            targets: ["MacWindowSwitchCLI"]
        )
    ],
    dependencies: [
        // ArgumentParser for CLI only
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        // Main library - zero external dependencies
        .target(
            name: "MacWindowSwitch",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v5)  // Use Swift 5 mode for Phase 0 parity port
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                // SkyLight is a private framework
                .unsafeFlags(["-Xlinker", "-F/System/Library/PrivateFrameworks"]),
                .unsafeFlags(["-Xlinker", "-framework", "-Xlinker", "SkyLight"])
            ]
        ),

        // CLI tool
        .executableTarget(
            name: "MacWindowSwitchCLI",
            dependencies: [
                "MacWindowSwitch",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)  // Use Swift 5 mode for Phase 0 parity port
            ]
        ),

        // Tests
        .testTarget(
            name: "MacWindowSwitchTests",
            dependencies: ["MacWindowSwitch"]
        )
    ]
)
