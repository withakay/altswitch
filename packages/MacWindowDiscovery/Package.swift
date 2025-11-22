// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacWindowDiscovery",
    platforms: [
        .macOS("13.0")  // Minimum macOS 13 for Swift Concurrency features
    ],
    products: [
        // Library product for embedding in apps
        .library(
            name: "MacWindowDiscovery",
            targets: ["MacWindowDiscovery"]
        ),
        // CLI tool product
        .executable(
            name: "mac-window-discovery",
            targets: ["MacWindowDiscoveryCLI"]
        ),
        // Debug GUI app
        .executable(
            name: "mac-window-discovery-debug",
            targets: ["MacWindowDiscoveryDebug"]
        )
    ],
    dependencies: [
        // Zero external dependencies for core library
        // ArgumentParser for CLI only
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        // Main library target
        .target(
            name: "MacWindowDiscovery",
            dependencies: []
        ),
        // CLI target
        .executableTarget(
            name: "MacWindowDiscoveryCLI",
            dependencies: [
                "MacWindowDiscovery",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        // Debug GUI app target
        .executableTarget(
            name: "MacWindowDiscoveryDebug",
            dependencies: [
                "MacWindowDiscovery"
            ]
        ),
        // Test target
        .testTarget(
            name: "MacWindowDiscoveryTests",
            dependencies: ["MacWindowDiscovery", "MacWindowDiscoveryCLI"],
            resources: [
                .copy("INTEGRATION_TESTS.md")
            ]
        )
    ]
)
