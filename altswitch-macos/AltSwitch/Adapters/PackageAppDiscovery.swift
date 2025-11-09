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
    Task { @MainActor in
      self.engine.startMonitoring()

      // Poll for changes and notify callback
      // TODO: Replace with proper event stream when package supports it
      await self.setupChangeMonitoring()
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

    // Get discovery options
    var options = MacWindowDiscovery.WindowDiscoveryOptions.default
    options.excludeSystemProcesses = true
    options.bundleIdentifierBlacklist = Self.systemProcessesToSkip

    // Discover windows using package
    let packageWindows = try await engine.discoverWindows(options: options)
    print("📦 [PackageAppDiscovery.fetchRunningApps] Package discovered \(packageWindows.count) windows")

    // CRITICAL: Cache AXUIElements for cross-space window switching
    // We must cache them NOW while windows are accessible, before switching spaces
    await cacheAXElementsForWindows(packageWindows)

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
          if window.title.isEmpty, let axTitle = axTitleOverlay[CGWindowID(window.id)] {
            displayTitle = axTitle
            print("📦 [PackageAppDiscovery] Using AX title '\(axTitle)' for window \(window.id) (CG title was empty)")
          } else {
            displayTitle = window.title
          }

          var appInfo = AppInfo(
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
        var appInfo = AppInfo(
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

    // Discover windows for this specific process
    let packageWindows = try await engine.discoverWindows(
      forProcessID: app.processIdentifier
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

    let windows = try await engine.discoverWindows(options: options)

    // Create debug output
    var debugOutput = """
    # AltSwitch Window Debug Information
    Generated: \(Date())
    Package Version: MacWindowDiscovery v0.5.0
    Total Windows: \(windows.count)

    """

    // Group by application
    let groupedByApp = Dictionary(grouping: windows) { window in
      AppGroupKey(
        processID: window.processID,
        appName: window.applicationName ?? "Unknown",
        bundleID: window.bundleIdentifier ?? "unknown"
      )
    }

    for (key, appWindows) in groupedByApp.sorted(by: { $0.key.processID < $1.key.processID }) {
      let processID = key.processID
      let appName = key.appName
      let bundleID = key.bundleID

      debugOutput += """

      ## \(appName) (\(bundleID))
      Process ID: \(processID)
      Windows: \(appWindows.count)

      """

      for window in appWindows {
        debugOutput += """

        ### Window \(window.id)
        - Title: "\(window.title)"
        - Bounds: \(window.bounds)
        - Alpha: \(window.alpha)
        - Layer: \(window.layer)
        - On Screen: \(window.isOnScreen)
        - Hidden: \(window.isHidden)
        - Minimized: \(window.isMinimized)
        - Fullscreen: \(window.isFullscreen)
        - Focused: \(window.isFocused)
        - Space IDs: \(window.spaceIDs)
        - On All Spaces: \(window.isOnAllSpaces)
        - Role: \(window.role ?? "nil")
        - Subrole: \(window.subrole ?? "nil")
        - Captured At: \(window.capturedAt)

        """
      }
    }

    // Save to file
    let fileManager = FileManager.default
    let configDir = fileManager.homeDirectoryForCurrentUser
      .appendingPathComponent(".config")
      .appendingPathComponent("altswitch")
      .appendingPathComponent("debug")

    try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)

    let debugFile = configDir.appendingPathComponent("window-debug-\(Date().timeIntervalSince1970).md")
    try debugOutput.write(to: debugFile, atomically: true, encoding: .utf8)

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

  /// Cache AXUIElements for discovered windows (critical for cross-space switching)
  ///
  /// AltTab approach: Cache the AXUIElement when the window is first discovered
  /// (while it's accessible) so it can be used later when switching to a window
  /// on another space (when it's inaccessible via normal AX API).
  ///
  /// - Parameter windows: Array of discovered windows
  @MainActor
  private func cacheAXElementsForWindows(_ windows: [MacWindowDiscovery.WindowInfo]) async {
    // Check permissions
    guard AXIsProcessTrusted() else {
      print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] No AX permissions, skipping cache")
      return
    }

    // Clear title overlay from previous refresh
    axTitleOverlay.removeAll()

    // Group windows by process ID to minimize AX API calls
    let windowsByProcess = Dictionary(grouping: windows) { $0.processID }

    print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] Caching AX elements for \(windowsByProcess.count) processes")
    print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] Package discovered window IDs: \(windows.map { $0.id }.sorted())")

    for (processID, processWindows) in windowsByProcess {
      // Create application AXUIElement
      let appElement = AXUIElementCreateApplication(processID)

      // Get all windows from AX API
      var windowsValue: CFTypeRef?
      let result = AXUIElementCopyAttributeValue(
        appElement,
        kAXWindowsAttribute as CFString,
        &windowsValue
      )

      guard result == .success, let axWindows = windowsValue as? [AXUIElement] else {
        print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] ❌ Failed to get AX windows for pid \(processID)")
        print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    AXError code: \(result.rawValue)")
        print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    windowsValue type: \(windowsValue != nil ? String(describing: type(of: windowsValue!)) : "nil")")

        // SOLUTION: When all windows are on non-current spaces, kAXWindowsAttribute returns 0 windows.
        // Try creating AXUIElements directly by querying at window positions.
        print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] 🔄 Attempting direct element creation for \(processWindows.count) windows")
        await tryDirectElementCreation(for: processWindows, processID: processID)
        continue
      }

      print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] Got \(axWindows.count) AX windows for pid \(processID)")
      print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] Process \(processID) has \(processWindows.count) discovered windows")

      // SOLUTION: When all windows are on non-current spaces, kAXWindowsAttribute returns success with empty array
      if axWindows.isEmpty && !processWindows.isEmpty {
        print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] 🔄 Empty AX windows but have \(processWindows.count) discovered windows")
        print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] 🔄 Attempting direct element creation (windows likely on non-current spaces)")
        await tryDirectElementCreation(for: processWindows, processID: processID)
        continue
      }

      // DEBUG: Show what MacWindowDiscovery knows about each window
      for window in processWindows {
        print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] === Discovered Window \(window.id) ===")
        print("📦   CGWindowList title: '\(window.title)'")
        print("📦   bounds: \(window.bounds)")
        print("📦   layer: \(window.layer), alpha: \(window.alpha)")
        print("📦   isOnScreen: \(window.isOnScreen), isMinimized: \(window.isMinimized)")
        print("📦   isFocused: \(window.isFocused), isHidden: \(window.isHidden)")
      }

      // Build a reverse mapping: AX title -> discovered window IDs
      // This handles cases where CGWindowList title is empty but AX title exists
      var titleToWindowIDs: [String: [UInt32]] = [:]
      for window in processWindows {
        if !window.title.isEmpty {
          titleToWindowIDs[window.title, default: []].append(window.id)
        }
      }

      // Try multiple strategies to match and cache AX windows
      for (index, axWindow) in axWindows.enumerated() {
        var cached = false

        // DEBUG: Try reading various AX attributes to see what's accessible
        print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] === Window[\(index)] AX Diagnostics ===")

        var titleVal: CFTypeRef?
        let titleRes = AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleVal)
        print("📦   kAXTitleAttribute: \(titleRes.rawValue) -> \(titleRes == .success ? (titleVal as? String ?? "nil") : "FAILED")")

        var roleVal: CFTypeRef?
        let roleRes = AXUIElementCopyAttributeValue(axWindow, kAXRoleAttribute as CFString, &roleVal)
        print("📦   kAXRoleAttribute: \(roleRes.rawValue) -> \(roleRes == .success ? (roleVal as? String ?? "nil") : "FAILED")")

        var subroleVal: CFTypeRef?
        let subroleRes = AXUIElementCopyAttributeValue(axWindow, kAXSubroleAttribute as CFString, &subroleVal)
        print("📦   kAXSubroleAttribute: \(subroleRes.rawValue) -> \(subroleRes == .success ? (subroleVal as? String ?? "nil") : "FAILED")")

        var focusedVal: CFTypeRef?
        let focusedRes = AXUIElementCopyAttributeValue(axWindow, kAXFocusedAttribute as CFString, &focusedVal)
        print("📦   kAXFocusedAttribute: \(focusedRes.rawValue)")

        var minimizedVal: CFTypeRef?
        let minimizedRes = AXUIElementCopyAttributeValue(axWindow, kAXMinimizedAttribute as CFString, &minimizedVal)
        print("📦   kAXMinimizedAttribute: \(minimizedRes.rawValue)")

        var mainVal: CFTypeRef?
        let mainRes = AXUIElementCopyAttributeValue(axWindow, kAXMainAttribute as CFString, &mainVal)
        print("📦   kAXMainAttribute: \(mainRes.rawValue)")

        // STRATEGY 1: Try to get _AXWindowID directly (works for same-space windows)
        var windowIDValue: CFTypeRef?
        let idResult = AXUIElementCopyAttributeValue(axWindow, "_AXWindowID" as CFString, &windowIDValue)
        print("📦   _AXWindowID: \(idResult.rawValue) -> \(idResult == .success ? (windowIDValue as? UInt32 ?? 0) : 0)")

        if idResult == .success, let windowID = windowIDValue as? UInt32 {
          print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] Window[\(index)] _AXWindowID=\(windowID) ✅")
          AXElementCache.shared.set(axWindow, for: CGWindowID(windowID))

          // Also try to get the title for UI (even though window is on current space)
          var titleValue: CFTypeRef?
          if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue) == .success,
             let axTitle = titleValue as? String, !axTitle.isEmpty {
            axTitleOverlay[CGWindowID(windowID)] = axTitle
          }

          cached = true
        } else {
          print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] Window[\(index)] _AXWindowID failed: \(idResult.rawValue)")

          // STRATEGY 2: Match by AX title (works for cross-space windows!)
          var titleValue: CFTypeRef?
          let titleResult = AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)

          if titleResult == .success, let axTitle = titleValue as? String, !axTitle.isEmpty {
            print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] Window[\(index)] AX title='\(axTitle)'")

            // CRITICAL: Store the AX title for ALL windows, even if they have CGWindowList titles
            // This ensures cross-space windows have titles in the UI before manual activation

            // Try exact title match
            if let matchedIDs = titleToWindowIDs[axTitle], let firstMatch = matchedIDs.first {
              print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] ✅ Matched by title to window ID \(firstMatch)")
              AXElementCache.shared.set(axWindow, for: CGWindowID(firstMatch))
              axTitleOverlay[CGWindowID(firstMatch)] = axTitle  // Store AX title for UI
              cached = true

              // Remove from map to avoid matching the same window twice
              if matchedIDs.count == 1 {
                titleToWindowIDs.removeValue(forKey: axTitle)
              } else {
                titleToWindowIDs[axTitle] = Array(matchedIDs.dropFirst())
              }
            } else {
              // STRATEGY 3: If we have exactly N AX windows and N discovered windows,
              // and only 1 discovered window is unmatched, match them
              let unmatchedWindows = processWindows.filter { window in
                // A window is unmatched if no AX element has been cached for it yet
                AXElementCache.shared.get(for: CGWindowID(window.id)) == nil
              }

              if processWindows.count == axWindows.count && unmatchedWindows.count == 1 {
                let unmatchedID = unmatchedWindows[0].id
                print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] ✅ Last unmatched pair - caching as window ID \(unmatchedID)")
                print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    (AX title='\(axTitle)' vs discovered title='\(unmatchedWindows[0].title)')")
                AXElementCache.shared.set(axWindow, for: CGWindowID(unmatchedID))
                axTitleOverlay[CGWindowID(unmatchedID)] = axTitle  // Store AX title for UI
                cached = true
              } else if !unmatchedWindows.isEmpty {
                // STRATEGY 4: Match by window bounds (position + size)
                // This works even when titles don't match
                var positionValue: CFTypeRef?
                var sizeValue: CFTypeRef?
                let posResult = AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue)
                let sizeResult = AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue)

                if posResult == .success && sizeResult == .success,
                   let position = positionValue as! AXValue?,
                   let size = sizeValue as! AXValue? {
                  var axPoint = CGPoint.zero
                  var axSize = CGSize.zero
                  AXValueGetValue(position, .cgPoint, &axPoint)
                  AXValueGetValue(size, .cgSize, &axSize)
                  let axBounds = CGRect(origin: axPoint, size: axSize)

                  print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] Window[\(index)] AX bounds: \(axBounds)")

                  // Find unmatched window with matching bounds (allow 1px tolerance for rounding)
                  if let matchedWindow = unmatchedWindows.first(where: { window in
                    abs(window.bounds.origin.x - axBounds.origin.x) <= 1 &&
                    abs(window.bounds.origin.y - axBounds.origin.y) <= 1 &&
                    abs(window.bounds.width - axBounds.width) <= 1 &&
                    abs(window.bounds.height - axBounds.height) <= 1
                  }) {
                    print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] ✅ Matched by bounds to window ID \(matchedWindow.id)")
                    print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    (discovered bounds: \(matchedWindow.bounds))")
                    AXElementCache.shared.set(axWindow, for: CGWindowID(matchedWindow.id))
                    axTitleOverlay[CGWindowID(matchedWindow.id)] = axTitle  // Store AX title for UI
                    cached = true
                  } else {
                    print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] ⚠️ No bounds match - unmatched bounds:")
                    for window in unmatchedWindows {
                      print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    Window \(window.id): \(window.bounds)")
                    }
                  }
                } else {
                  print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] ⚠️ No match for AX title '\(axTitle)'")
                  print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    Available discovered titles: \(processWindows.map { $0.title })")
                  print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    Unmatched count: \(unmatchedWindows.count)")
                  print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    Could not get AX bounds: pos=\(posResult.rawValue), size=\(sizeResult.rawValue)")
                }
              } else {
                print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] ⚠️ No match for AX title '\(axTitle)'")
                print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    Available discovered titles: \(processWindows.map { $0.title })")
                print("📦 [PackageAppDiscovery.cacheAXElementsForWindows]    Unmatched count: 0")
              }
            }
          } else {
            print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] Window[\(index)] AX title failed: \(titleResult.rawValue)")
          }
        }

        if !cached {
          print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] ❌ Window[\(index)] could not be cached")
        }
      }

      // Summary for this process
      print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] === Process \(processID) Summary ===")
      for window in processWindows {
        let isCached = AXElementCache.shared.get(for: CGWindowID(window.id)) != nil
        let hasOverlayTitle = axTitleOverlay[CGWindowID(window.id)] != nil
        print("📦   Window \(window.id): cached=\(isCached), overlayTitle=\(hasOverlayTitle), cgTitle='\(window.title)'")
      }
    }

    print(
      "📦 [PackageAppDiscovery.cacheAXElementsForWindows] === FINAL SUMMARY ==="
    )
    print(
      "📦 [PackageAppDiscovery.cacheAXElementsForWindows] Cached \(AXElementCache.shared.count) AX elements"
    )
    print(
      "📦 [PackageAppDiscovery.cacheAXElementsForWindows] Title overlay has \(axTitleOverlay.count) entries"
    )

    // Show which discovered windows are NOT cached
    let uncachedWindows = windows.filter { AXElementCache.shared.get(for: CGWindowID($0.id)) == nil }
    if !uncachedWindows.isEmpty {
      print("📦 [PackageAppDiscovery.cacheAXElementsForWindows] ⚠️ UNCACHED WINDOWS (\(uncachedWindows.count)):")
      for window in uncachedWindows {
        print("📦     Window \(window.id): '\(window.title)' - pid \(window.processID)")
      }
    }
  }

  /// Title overlay: Maps window ID -> AX title discovered during caching
  /// This supplements MacWindowDiscovery's titles for cross-space windows
  private var axTitleOverlay: [CGWindowID: String] = [:]

  /// Try to create AXUIElements directly by querying at window positions
  ///
  /// This is used when kAXWindowsAttribute returns 0 windows (all windows on non-current spaces).
  /// We query the system-wide accessibility element at each window's position to get its AXUIElement.
  ///
  /// - Parameters:
  ///   - windows: Windows to try creating elements for
  ///   - processID: Process ID to validate elements belong to correct app
  @MainActor
  private func tryDirectElementCreation(for windows: [MacWindowDiscovery.WindowInfo], processID: pid_t) async {
    let systemWide = AXUIElementCreateSystemWide()

    for window in windows {
      print("📦 [tryDirectElementCreation] Trying window \(window.id) at bounds \(window.bounds)")

      // Query at window center
      let centerX = Float(window.bounds.midX)
      let centerY = Float(window.bounds.midY)

      var element: AXUIElement?
      let result = AXUIElementCopyElementAtPosition(systemWide, centerX, centerY, &element)

      if result == .success, let axElement = element {
        print("📦 [tryDirectElementCreation] ✅ Got element at position (\(centerX), \(centerY))")

        // Verify this element belongs to our process
        var pidValue: pid_t = 0
        let pidResult = AXUIElementGetPid(axElement, &pidValue)

        if pidResult == .success && pidValue == processID {
          print("📦 [tryDirectElementCreation] ✅ Element belongs to pid \(processID)")

          // Check if this is a window element
          var roleValue: CFTypeRef?
          let roleResult = AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue)

          if roleResult == .success, let role = roleValue as? String {
            print("📦 [tryDirectElementCreation]    Role: \(role)")

            if role == kAXWindowRole as String {
              // Cache this window element
              AXElementCache.shared.set(axElement, for: CGWindowID(window.id))

              // Try to get title for overlay
              var titleValue: CFTypeRef?
              if AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &titleValue) == .success,
                 let axTitle = titleValue as? String, !axTitle.isEmpty {
                axTitleOverlay[CGWindowID(window.id)] = axTitle
                print("📦 [tryDirectElementCreation] ✅ Cached window \(window.id) with title '\(axTitle)'")
              } else {
                print("📦 [tryDirectElementCreation] ✅ Cached window \(window.id) (no title)")
              }
            } else {
              print("📦 [tryDirectElementCreation] ⚠️ Element is not a window, it's a \(role)")
              // The element at this position might be a child element (button, etc)
              // Try to get the parent window
              var parentValue: CFTypeRef?
              if AXUIElementCopyAttributeValue(axElement, kAXParentAttribute as CFString, &parentValue) == .success,
                 let parentElement = parentValue as! AXUIElement? {
                var parentRoleValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(parentElement, kAXRoleAttribute as CFString, &parentRoleValue) == .success,
                   let parentRole = parentRoleValue as? String,
                   parentRole == kAXWindowRole as String {
                  print("📦 [tryDirectElementCreation] ✅ Found parent window element")

                  // Cache the parent window
                  AXElementCache.shared.set(parentElement, for: CGWindowID(window.id))

                  // Get title from parent
                  var titleValue: CFTypeRef?
                  if AXUIElementCopyAttributeValue(parentElement, kAXTitleAttribute as CFString, &titleValue) == .success,
                     let axTitle = titleValue as? String, !axTitle.isEmpty {
                    axTitleOverlay[CGWindowID(window.id)] = axTitle
                    print("📦 [tryDirectElementCreation] ✅ Cached window \(window.id) with title '\(axTitle)' via parent")
                  }
                }
              }
            }
          }
        } else {
          print("📦 [tryDirectElementCreation] ⚠️ Element belongs to different pid: \(pidValue) (expected \(processID))")
        }
      } else {
        print("📦 [tryDirectElementCreation] ❌ Failed to get element at position: \(result.rawValue)")
      }
    }
  }

  /// Set up monitoring for cache changes
  ///
  /// Note: This polls the cache statistics for now. Ideally the package would
  /// expose an AsyncStream<Void> for cache change events.
  ///
  /// CRITICAL: This monitoring is currently DISABLED to prevent infinite loops.
  /// The callback triggers fetchRunningApps(), which triggers the callback again.
  /// Need to implement proper change detection that doesn't trigger on reads.
  private func setupChangeMonitoring() async {
    // DISABLED: Causing infinite loop - every cache access triggers callback
    // which calls fetchRunningApps() which accesses cache, triggering callback...
    return

    var lastChangeCounter = 0

    // Poll for cache changes every 0.5 seconds
    while !Task.isCancelled {
      try? await Task.sleep(nanoseconds: 500_000_000)

      let stats = await engine.cacheStatistics()

      // Use hits + misses as a simple change counter
      // Every cache access (hit or miss) increments this counter
      let derivedCounter = stats.hits + stats.misses

      if derivedCounter > lastChangeCounter {
        lastChangeCounter = derivedCounter
        if let callback = self.cacheChangeCallback {
          callback()
        }
      }
    }
  }

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
