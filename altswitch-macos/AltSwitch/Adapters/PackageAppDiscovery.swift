#if canImport(MacWindowDiscovery)
//
//  PackageAppDiscovery.swift
//  AltSwitch
//
//  AppDiscoveryProtocol implementation using MacWindowDiscovery package
//

import AppKit
import Foundation
import MacWindowDiscovery

/// AppDiscoveryProtocol implementation using MacWindowDiscovery package
///
/// This adapter wraps the MacWindowDiscovery.CachedWindowDiscoveryEngine
/// and converts its types to AltSwitch's types (AppInfo, WindowInfo).
///
/// Benefits of using the package:
/// - Battle-tested window discovery logic
/// - Event-driven cache invalidation
/// - Comprehensive test coverage
/// - Shared codebase with CLI tool
@MainActor
final class PackageAppDiscovery: AppDiscoveryProtocol {
  // MARK: - Dependencies

  /// Small hashable keys to group windows by app without using tuples
  private struct AppKey: Hashable {
    let processID: pid_t
    let bundleID: String
  }

  private struct AppGroupKey: Hashable {
    let processID: pid_t
    let appName: String
    let bundleID: String
  }

  /// Package discovery engine with caching
  private let engine: MacWindowDiscovery.CachedWindowDiscoveryEngine

  /// Cache change callback
  private var cacheChangeCallback: (@MainActor () -> Void)?

  /// Application name exclude list (all windows excluded)
  var applicationNameExcludeList: Set<String> = []

  /// Untitled window exclude list (only untitled windows excluded)
  var untitledWindowExcludeList: Set<String> = []

  /// Icon cache (shared across all instances)
  private static var iconCache: NSCache<NSString, NSImage> = {
    let cache = NSCache<NSString, NSImage>()
    cache.countLimit = 256
    return cache
  }()

  /// System processes to skip (matches old implementation)
  private static let systemProcessesToSkip: Set<String> = [
    "com.apple.dock",
    "com.apple.WindowManager",
    "com.apple.controlcenter",
    "com.apple.Spotlight",
    "com.apple.notificationcenterui",
    "com.apple.systemuiserver",
  ]

  // MARK: - Initialization

  /// Initialize with package engine
  init() {
    // Create cached engine with 2 second TTL (matches old implementation)
    self.engine = MacWindowDiscovery.CachedWindowDiscoveryEngine(cacheTTL: 2.0)

    // Set up event monitoring for cache invalidation
    self.engine.startMonitoring()
    self.engine.onInvalidation { [weak self] _ in
      guard let self else { return }
      Task { @MainActor in
        self.cacheChangeCallback?()
      }
    }
  }

  deinit {
    let engine = self.engine // Capture strongly to avoid capturing self in closure
    Task { @MainActor in
      engine.stopMonitoring()
    }
  }

  // MARK: - AppDiscoveryProtocol

  /// Fetch all currently running applications with their windows
  ///
  /// - Parameter showIndividualWindows: If true, returns one AppInfo per window
  /// - Returns: Array of AppInfo with current window state
  func fetchRunningApps(showIndividualWindows: Bool) async throws -> [AppInfo] {
    print("📦 [PackageAppDiscovery.fetchRunningApps] Discovering apps from package, showIndividualWindows: \(showIndividualWindows)")

    // Get discovery options with AX caching enabled
    var options = MacWindowDiscovery.WindowDiscoveryOptions.default
    options.excludeSystemProcesses = true
    options.bundleIdentifierBlacklist = Self.systemProcessesToSkip
    options.enableAXElementCaching = true
    options.collectTitleOverlay = true
    
    // Apply application filtering from configuration
    options.applicationNameExcludeList = applicationNameExcludeList
    options.untitledWindowExcludeList = untitledWindowExcludeList

    // Discover windows using package
    let packageWindows = try await engine.discoverWindows(options: options)
    print("📦 [PackageAppDiscovery.fetchRunningApps] Package discovered \(packageWindows.count) windows")

    // Group by application
    let groupedByApp = Dictionary(grouping: packageWindows) { window in
      AppKey(processID: window.processID, bundleID: window.bundleIdentifier ?? "unknown")
    }

    // Convert to AppInfo array
    var apps: [AppInfo] = []

    for (key, windows) in groupedByApp {
      let processID = key.processID
      let bundleID = key.bundleID

      // Find NSRunningApplication
      guard let runningApp = NSWorkspace.shared.runningApplications.first(where: {
        $0.processIdentifier == processID
      }) else {
        continue
      }

      // Get app icon
      let icon = Self.getIcon(for: runningApp)

      if showIndividualWindows {
        // Create one AppInfo per window
        for (index, window) in windows.enumerated() {
          // Use AX title overlay if MacWindowDiscovery's title is empty
          let displayTitle: String
          if window.title.isEmpty, let axTitle = MacWindowDiscovery.AXElementStore.shared.getTitle(for: CGWindowID(window.id)) {
            displayTitle = axTitle
            print("📦 [PackageAppDiscovery] Using AX title '\(axTitle)' for window \(window.id) (CG title was empty)")
          } else {
            displayTitle = window.title
          }

          let appInfo = AppInfo(
            bundleIdentifier: bundleID,
            localizedName: runningApp.localizedName ?? bundleID,
            processIdentifier: processID,
            icon: icon,
            isActive: runningApp.isActive,
            isHidden: runningApp.isHidden,
            windows: [window],
            url: runningApp.bundleURL,
            lastActivationTime: index == 0 ? Date() : Date.distantPast,
            windowTitle: displayTitle
          )
          // CRITICAL: Update space information for cross-space window switching
          appInfo.updateSpaceInfo()
          apps.append(appInfo)
        }
      } else {
        // Create one AppInfo per application
        let appInfo = AppInfo(
          bundleIdentifier: bundleID,
          localizedName: runningApp.localizedName ?? bundleID,
          processIdentifier: processID,
          icon: icon,
          isActive: runningApp.isActive,
          isHidden: runningApp.isHidden,
          windows: windows,
          url: runningApp.bundleURL,
          lastActivationTime: runningApp.isActive ? Date() : Date.distantPast,
          windowTitle: nil
        )
        // CRITICAL: Update space information for cross-space window switching
        appInfo.updateSpaceInfo()
        apps.append(appInfo)
      }
    }

    print("📦 [PackageAppDiscovery.fetchRunningApps] Created \(apps.count) AppInfo objects")
    return apps
  }

  /// Refresh window information for a specific application
  ///
  /// - Parameter app: The application to refresh windows for
  /// - Returns: Array of refreshed WindowInfo
  func refreshWindows(for app: AppInfo) async throws -> [MacWindowDiscovery.WindowInfo] {
    print("📦 [PackageAppDiscovery.refreshWindows] Refreshing windows for \(app.bundleIdentifier)")

    // Invalidate cache for this process to force fresh discovery
    await engine.invalidateCache(forProcessID: app.processIdentifier)

    // Discover windows for this specific process with AX caching
    var options = MacWindowDiscovery.WindowDiscoveryOptions.default
    options.enableAXElementCaching = true
    options.collectTitleOverlay = true
    
    // Apply application filtering from configuration
    options.applicationNameExcludeList = applicationNameExcludeList
    options.untitledWindowExcludeList = untitledWindowExcludeList
    
    let packageWindows = try await engine.discoverWindows(
      forProcessID: app.processIdentifier,
      options: options
    )

    print("📦 [PackageAppDiscovery.refreshWindows] Refreshed \(packageWindows.count) windows")
    return packageWindows
  }

  /// Generate debug information for all windows and save to file
  ///
  /// - Returns: URL of the generated debug file
  func dumpWindowDebugInfo() async throws -> URL {
    print("📦 [PackageAppDiscovery.dumpWindowDebugInfo] Generating debug info")

    // Discover all windows with complete options
    var options = MacWindowDiscovery.WindowDiscoveryOptions.complete
    options.includeSpaceInfo = true
    options.enableAXElementCaching = true

    let windows = try await engine.discoverWindows(options: options)

    // Use package's debug dumper
    let debugFile = try MacWindowDiscovery.WindowDebugDumper.shared.saveDebugReport(
      windows: windows,
      includeSpaceInfo: true
    )

    print("📦 [PackageAppDiscovery.dumpWindowDebugInfo] Saved debug info to \(debugFile.path)")
    return debugFile
  }

  /// Set the callback to invoke when the underlying cache changes
  ///
  /// - Parameter callback: Closure to invoke on MainActor when cache changes
  func onCacheDidChange(_ callback: @escaping @MainActor () -> Void) {
    self.cacheChangeCallback = callback
  }

  // MARK: - Private Helpers

  /// Get app icon with caching
  private static func getIcon(for app: NSRunningApplication) -> NSImage {
    let bundleID = app.bundleIdentifier ?? "unknown"

    // Check cache first
    if let cachedIcon = iconCache.object(forKey: bundleID as NSString) {
      return cachedIcon
    }

    // Get icon from app
    let icon = app.icon ?? NSImage(
      systemSymbolName: "app.fill",
      accessibilityDescription: "App icon"
    ) ?? NSImage()

    // Cache it
    iconCache.setObject(icon, forKey: bundleID as NSString)

    return icon
  }
}

#else
import AppKit
import Foundation

/// Fallback implementation when MacWindowDiscovery package is unavailable.
/// Provides empty data so the app can compile and run minimal functionality.
@MainActor
final class PackageAppDiscovery: AppDiscoveryProtocol {
  init() {
    print("📦 [PackageAppDiscovery] MacWindowDiscovery not available; using fallback implementation")
  }

  deinit {}

  func fetchRunningApps(showIndividualWindows: Bool) async throws -> [AppInfo] {
    print("📦 [PackageAppDiscovery.fetchRunningApps] Fallback: returning empty list (showIndividualWindows: \(showIndividualWindows))")
    return []
  }

  func refreshWindows(for app: AppInfo) async throws -> [MacWindowDiscovery.WindowInfo] {
    print("📦 [PackageAppDiscovery.refreshWindows] Fallback: returning empty windows for app: \(app.bundleIdentifier)")
    return []
  }

  func dumpWindowDebugInfo() async throws -> URL {
    print("📦 [PackageAppDiscovery.dumpWindowDebugInfo] Fallback: generating empty debug info")

    let fileManager = FileManager.default
    let configDir = fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent(".config")
      .appendingPathComponent("altswitch")
      .appendingPathComponent("debug")

    try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)

    let debugFile = configDir.appendingPathComponent("window-debug-\(Date().timeIntervalSince1970)-fallback.md")
    let debugOutput = """
    # AltSwitch Window Debug Information (Fallback)
    Generated: \(Date())
    Package Version: (MacWindowDiscovery unavailable)
    Total Windows: 0
    """
    try debugOutput.write(to: debugFile, atomically: true, encoding: .utf8)
    return debugFile
  }

  func onCacheDidChange(_ callback: @escaping @MainActor () -> Void) {
    // Fallback has no cache; nothing to monitor.
  }
}
#endif
