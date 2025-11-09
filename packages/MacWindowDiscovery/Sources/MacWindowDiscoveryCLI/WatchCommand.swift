import Foundation
import ArgumentParser
import MacWindowDiscovery

struct WatchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "watch",
        abstract: "Watch for window changes in real-time"
    )

    @Option(name: .shortAndLong, help: "Refresh interval in seconds")
    var interval: Double = 1.0

    @Option(name: .shortAndLong, help: "Output format (table, json, compact)")
    var format: OutputFormat = .compact

    @Flag(name: .long, help: "Only windows on active Space")
    var activeSpace = false

    @Option(name: .shortAndLong, help: "Filter by bundle identifier")
    var bundleID: String?

    func run() throws {
        print("Watching for window changes (press Ctrl+C to stop)...")
        print("Refresh interval: \(interval)s\n")

        let engine = try runAsync {
            await CachedWindowDiscoveryEngine(cacheTTL: interval)
        }

        var options: WindowDiscoveryOptions = .default
        if !activeSpace {
            options.includeInactiveSpaces = true
        } else {
            options.includeInactiveSpaces = false
        }

        if let bundleID = bundleID {
            options.bundleIdentifierWhitelist = [bundleID]
        }

        var previousCount = 0
        let formatter = OutputFormatter(format: format)

        while true {
            let finalOptions = options  // Capture as constant for sendable closure
            let windows = try runAsync {
                try await engine.discoverWindows(options: finalOptions)
            }
            let sortedWindows = windows.sortedByApp()

            // Clear screen for table format
            if format == .table {
                print("\u{001B}[2J\u{001B}[H")  // ANSI clear screen
            }

            print("[\(Date().formatted(date: .omitted, time: .standard))] Found \(windows.count) windows")

            if windows.count != previousCount {
                print("  → Window count changed: \(previousCount) → \(windows.count)")
            }

            // Get cache stats
            let stats = try runAsync {
                await engine.cacheStatistics()
            }
            if stats.hits + stats.misses > 0 {
                print("  Cache: \(stats.hits) hits, \(stats.misses) misses (hit rate: \(String(format: "%.1f%%", stats.hitRate * 100)))")
            }

            if format == .table {
                print()
                formatter.format(windows: sortedWindows)
            }

            previousCount = windows.count

            Thread.sleep(forTimeInterval: interval)
        }
    }
}
