import Foundation
import ArgumentParser
import MacWindowDiscovery

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all windows on the system"
    )

    @Option(name: .shortAndLong, help: "Output format (table, json, compact)")
    var format: OutputFormat = .compact

    @Flag(name: .long, help: "Include hidden windows")
    var includeHidden = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Include minimized windows (default: true)")
    var includeMinimized = true

    @Flag(name: .long, help: "Use fast mode (no Accessibility API)")
    var fast = false

    @Flag(name: .long, help: "Only windows on active Space")
    var activeSpace = false

    @Option(name: .shortAndLong, help: "Filter by bundle identifier")
    var bundleID: String?

    @Flag(name: .long, help: "Use caching for better performance")
    var cached = false

    @Option(name: .long, help: "Minimum window width")
    var minWidth: Double?

    @Option(name: .long, help: "Minimum window height")
    var minHeight: Double?

    @Option(name: .long, parsing: .upToNextOption, help: "Exclude all windows from these applications (comma-separated app names)")
    var excludeApps: [String] = []

    @Option(name: .long, parsing: .upToNextOption, help: "Exclude untitled windows from these applications (comma-separated app names)")
    var excludeUntitledApps: [String] = []

    func run() throws {
        // Build options
        var options: WindowDiscoveryOptions = fast ? .fast : .default
        options.includeHidden = includeHidden
        options.includeMinimized = includeMinimized

        if !activeSpace {
            options.includeInactiveSpaces = true
        } else {
            options.includeInactiveSpaces = false
        }

        if let bundleID = bundleID {
            options.bundleIdentifierWhitelist = [bundleID]
        }

        if let minWidth = minWidth, let minHeight = minHeight {
            options.minimumSize = CGSize(width: minWidth, height: minHeight)
        }

        if !excludeApps.isEmpty {
            options.applicationNameExcludeList = Set(excludeApps)
        }

        if !excludeUntitledApps.isEmpty {
            options.untitledWindowExcludeList = Set(excludeUntitledApps)
        }

        // Discover windows synchronously by wrapping async call
        let finalOptions = options  // Capture as constant for sendable closure
        let windows: [WindowInfo]
        if cached {
            windows = try runAsync {
                let engine = await CachedWindowDiscoveryEngine()
                return try await engine.discoverWindows(options: finalOptions)
            }
        } else {
            windows = try runAsync {
                let engine = WindowDiscoveryEngine()
                return try await engine.discoverWindows(options: finalOptions)
            }
        }

        // Sort by app name, then title
        let sortedWindows = windows.sortedByApp()

        // Format output
        let formatter = OutputFormatter(format: format)
        formatter.format(windows: sortedWindows)
    }
}
