import Foundation
import ArgumentParser
import MacWindowDiscovery

struct AppCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "app",
        abstract: "List windows for a specific application"
    )

    @Argument(help: "Bundle identifier (e.g., com.apple.Safari)")
    var bundleIdentifier: String

    @Option(name: .shortAndLong, help: "Output format (table, json, compact)")
    var format: OutputFormat = .table

    @Flag(name: .long, help: "Include hidden windows")
    var includeHidden = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Include minimized windows (default: true)")
    var includeMinimized = true

    func run() throws {
        var options = WindowDiscoveryOptions.default
        options.includeHidden = includeHidden
        options.includeMinimized = includeMinimized

        let finalOptions = options  // Capture as constant for sendable closure
        let finalBundleID = bundleIdentifier  // Capture as constant

        let engine = WindowDiscoveryEngine()
        let windows = try runAsync {
            try await engine.discoverWindows(
                forBundleIdentifier: finalBundleID,
                options: finalOptions
            )
        }

        if windows.isEmpty {
            print("No windows found for \(bundleIdentifier)")
            print("\nTip: Use 'list --format json' to see all bundle identifiers")
            return
        }

        // Print app info
        if let appName = windows.first?.applicationName {
            print("\nApplication: \(appName) (\(bundleIdentifier))")
            print("Windows: \(windows.count)\n")
        }

        let sortedWindows = windows.sortedByTitle()
        let formatter = OutputFormatter(format: format)
        formatter.format(windows: sortedWindows)
    }
}
