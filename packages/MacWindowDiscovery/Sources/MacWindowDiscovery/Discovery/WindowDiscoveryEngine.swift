import Foundation
import CoreGraphics
import AppKit
import ApplicationServices

/// Main engine for discovering windows on macOS
///
/// This class uses selective actor isolation: CGWindowList operations run on
/// any thread for maximum performance, while NSWorkspace and AX operations
/// are isolated to the main actor where required.
public final class WindowDiscoveryEngine: Sendable {

    // MARK: - Properties

    private let cgProvider: WindowProviderProtocol
    private let axProvider: AXWindowProviderProtocol
    private let workspaceProvider: WorkspaceProviderProtocol
    private let titleCache: WindowTitleCache

    private let validator = WindowValidator()

    // MARK: - Initialization

    /// Create a new discovery engine with default configuration
    public init(titleCache: WindowTitleCache? = nil) {
        self.cgProvider = CGWindowProvider()
        self.axProvider = AXWindowProvider()
        self.workspaceProvider = NSWorkspaceProvider()
        self.titleCache = titleCache ?? WindowTitleCache()
    }

    /// Create an engine with custom providers (for testing)
    public init(
        cgProvider: WindowProviderProtocol,
        axProvider: AXWindowProviderProtocol,
        workspaceProvider: WorkspaceProviderProtocol,
        titleCache: WindowTitleCache? = nil
    ) {
        self.cgProvider = cgProvider
        self.axProvider = axProvider
        self.workspaceProvider = workspaceProvider
        self.titleCache = titleCache ?? WindowTitleCache()
    }

    // MARK: - Permission Checking

    /// Check if accessibility permissions are granted
    public static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Request accessibility permissions (shows system dialog)
    @MainActor
    @discardableResult
    public static func requestAccessibilityPermission() -> Bool {
        // kAXTrustedCheckOptionPrompt is a global constant, safe to access
        // Using string literal as workaround for Swift 6 concurrency
        let options: CFDictionary = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Check if screen recording permission is granted
    public static func hasScreenRecordingPermission() -> Bool {
        // Simple check: try to get screen info
        guard let screen = NSScreen.main else { return false }
        return screen.frame != .zero
    }

    // MARK: - Discovery Operations

    /// Discover all windows matching the given options
    nonisolated public func discoverWindows(
        options: WindowDiscoveryOptions = .default
    ) async throws -> [WindowInfo] {
        // Step 1: Get raw window data from CG (nonisolated - fast)
        // Use .optionAll to get windows from all spaces, or .optionOnScreenOnly for active spaces only
        let cgOption: CGWindowListOption = options.includeInactiveSpaces ? .optionAll : .optionOnScreenOnly
        let cgWindows = try cgProvider.captureWindowList(option: cgOption)

        // Step 2: Validate windows
        let validWindows = cgWindows.filter { validator.isValid($0) }

        // Step 3: Get app metadata (MainActor)
        let apps = await MainActor.run {
            workspaceProvider.runningApplications()
        }

        // Build app lookup - filter out invalid process IDs and handle duplicates
        let validApps = apps.filter { $0.processID > 0 }
        let appLookup = Dictionary(
            validApps.map { ($0.processID, $0) },
            uniquingKeysWith: { first, _ in first } // Keep first app if duplicate PIDs
        )

        // Step 4: Get AX enrichment if needed (MainActor)
        let axLookup: [pid_t: [CGWindowID: AXWindowInfo]]
        if options.useAccessibilityAPI {
            axLookup = await buildAXLookup(for: validWindows, apps: apps)
        } else {
            axLookup = [:]
        }

        // Step 5: Get Space information if needed
        // We need space info if: we want to include it OR we need to filter by active space
        let spaceLookup: [CGWindowID: [Int]]
        let needSpaceInfo = options.includeSpaceInfo || !options.includeInactiveSpaces
        if needSpaceInfo && SpacesAPI.isAvailable() {
            spaceLookup = buildSpaceLookup(for: validWindows)
        } else {
            spaceLookup = [:]
        }

        // Step 6: Build WindowInfo objects
        let builder = WindowInfoBuilder(titleCache: titleCache)
        let filter = WindowFilterPolicy(options: options)

        var windows: [WindowInfo] = []
        for cgData in validWindows {
            guard let windowID = cgData[kCGWindowNumber as String] as? CGWindowID,
                  let pid = cgData[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }

            let axInfo = axLookup[pid]?[windowID]
            let appInfo = appLookup[pid]
            let spaces = spaceLookup[windowID] ?? []

            // Apply filters
            guard filter.shouldInclude(cgData, axInfo: axInfo, appInfo: appInfo, spaceIDs: spaces) else {
                continue
            }

            // Build WindowInfo
            let windowInfo = await builder.buildWindowInfo(
                from: cgData,
                axInfo: axInfo,
                appInfo: appInfo,
                spaces: spaces
            )
            windows.append(windowInfo)
        }

        // Post-processing: Remove windows without proper AX metadata if the app has other windows WITH proper metadata
        // This filters out settings windows, tool palettes, etc. for apps that have proper main windows
        if options.requireProperSubrole {
            return filterDuplicateWindowsWithoutAX(windows)
        }

        return windows
    }

    /// Filters out windows without proper AX metadata when the app has windows with proper AX metadata
    private func filterDuplicateWindowsWithoutAX(_ windows: [WindowInfo]) -> [WindowInfo] {
        // Group windows by process ID
        let windowsByPID = Dictionary(grouping: windows, by: { $0.processID })

        var filtered: [WindowInfo] = []

        for (_, appWindows) in windowsByPID {
            // Check if this app has any windows with proper subrole
            let validSubroles = ["AXStandardWindow", "AXDialog"]
            let hasProperWindows = appWindows.contains { window in
                window.subrole != nil && validSubroles.contains(window.subrole!)
            }

            if hasProperWindows {
                // Include windows with proper subrole OR windows on real spaces
                // (inactive space windows don't have AX metadata but are legitimate)
                filtered.append(contentsOf: appWindows.filter { window in
                    let hasProperSubrole = window.subrole != nil && validSubroles.contains(window.subrole!)
                    let isOnRealSpace = !window.spaceIDs.isEmpty
                    return hasProperSubrole || isOnRealSpace
                })
            } else {
                // No windows have proper subrole, keep all of them
                filtered.append(contentsOf: appWindows)
            }
        }

        return filtered
    }

    /// Discover windows for a specific process
    nonisolated public func discoverWindows(
        forProcessID processID: pid_t,
        options: WindowDiscoveryOptions = .default
    ) async throws -> [WindowInfo] {
        // Discover all windows
        let allWindows = try await discoverWindows(options: options)

        // Filter to specific process
        return allWindows.filter { $0.processID == processID }
    }

    /// Discover windows for a specific application
    nonisolated public func discoverWindows(
        forBundleIdentifier bundleIdentifier: String,
        options: WindowDiscoveryOptions = .default
    ) async throws -> [WindowInfo] {
        // Modify options to whitelist specific bundle ID
        var specificOptions = options
        specificOptions.bundleIdentifierWhitelist = [bundleIdentifier]

        return try await discoverWindows(options: specificOptions)
    }

    // MARK: - Application Discovery

    /// Get all running applications with their window counts
    @MainActor
    public func enumerateApplications() async -> [pid_t: (name: String, windowCount: Int)] {
        let apps = workspaceProvider.runningApplications()

        var result: [pid_t: (name: String, windowCount: Int)] = [:]

        for app in apps {
            // Get windows for this app
            do {
                let windows = try await discoverWindows(forProcessID: app.processID)
                let name = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
                result[app.processID] = (name, windows.count)
            } catch {
                // Skip apps that fail
                continue
            }
        }

        return result
    }

    // MARK: - Private Helpers

    private func buildAXLookup(
        for windows: [[String: Any]],
        apps: [AppInfo]
    ) async -> [pid_t: [CGWindowID: AXWindowInfo]] {
        // Extract PIDs outside MainActor context
        let pids = Set(windows.compactMap {
            $0[kCGWindowOwnerPID as String] as? pid_t
        })

        return await MainActor.run {
            var lookup: [pid_t: [CGWindowID: AXWindowInfo]] = [:]

            for pid in pids {
                guard let app = apps.first(where: { $0.processID == pid }),
                      let bundleID = app.bundleIdentifier else {
                    continue
                }

                let windowInfo = axProvider.buildWindowLookup(
                    for: pid,
                    bundleIdentifier: bundleID
                )
                lookup[pid] = windowInfo
            }

            return lookup
        }
    }

    private func buildSpaceLookup(
        for windows: [[String: Any]]
    ) -> [CGWindowID: [Int]] {
        var lookup: [CGWindowID: [Int]] = [:]

        for window in windows {
            guard let windowID = window[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }

            let spaces = SpacesAPI.getWindowSpaces(windowID)
            lookup[windowID] = spaces
        }

        return lookup
    }
}
