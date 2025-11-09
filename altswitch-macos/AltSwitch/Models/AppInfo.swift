//
//  AppInfo.swift
//  AltSwitch
//
//  Represents a running application with metadata for app switching
//

import AppKit
import Foundation
import MacWindowDiscovery

@Observable
final class AppInfo {
  let bundleIdentifier: String
  let localizedName: String
  let processIdentifier: pid_t
  let icon: NSImage
  var isActive: Bool
  var isHidden: Bool
  var windows: [MacWindowDiscovery.WindowInfo]
  let url: URL?
  var lastActivationTime: Date
  let windowTitle: String?  // Window title for individual window mode

  // Space tracking (ported from AltTab)
  var spaceIds: [CGSSpaceID] = []       // All spaces this window appears on
  var spaceIndexes: [SpaceIndex] = []   // UI indices of those spaces
  var isOnAllSpaces: Bool = false       // True if window appears on all spaces

  // Computed properties
  var windowCount: Int { windows.count }
  var displayName: String { localizedName.isEmpty ? bundleIdentifier : localizedName }

  init(
    bundleIdentifier: String,
    localizedName: String,
    processIdentifier: pid_t,
    icon: NSImage,
    isActive: Bool = false,
    isHidden: Bool = false,
    windows: [MacWindowDiscovery.WindowInfo] = [],
    url: URL? = nil,
    lastActivationTime: Date? = nil,
    windowTitle: String? = nil
  ) {
    // Validation
    precondition(!bundleIdentifier.isEmpty, "Bundle identifier must not be empty")
    precondition(processIdentifier > 0, "Process identifier must be positive")

    self.bundleIdentifier = bundleIdentifier
    self.localizedName = localizedName.isEmpty ? bundleIdentifier : localizedName
    self.processIdentifier = processIdentifier
    self.icon = icon
    self.isActive = isActive
    self.isHidden = isHidden
    self.windows = windows
    self.url = url
    // Set last activation time - if active now, use current time, otherwise use provided time or distant past
    self.lastActivationTime = lastActivationTime ?? (isActive ? Date() : Date.distantPast)
    self.windowTitle = windowTitle
  }
}

// MARK: - Identifiable

extension AppInfo: Identifiable {
  var id: String {
    if let windowTitle = windowTitle, !windows.isEmpty {
      // Individual window mode: use bundle ID + window ID for uniqueness
      return "\(bundleIdentifier)_\(windows[0].id)"
    }
    return bundleIdentifier
  }
}

// MARK: - Equatable

extension AppInfo: Equatable {
  static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
    lhs.bundleIdentifier == rhs.bundleIdentifier
      && lhs.processIdentifier == rhs.processIdentifier
  }
}

// MARK: - Hashable

extension AppInfo: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(bundleIdentifier)
    hasher.combine(processIdentifier)
  }
}

// MARK: - Sendable

extension AppInfo: @unchecked Sendable {}

// MARK: - Space Management

extension AppInfo {
  /// Update space tracking for this app's windows (ported from AltTab)
  func updateSpaceInfo() {
    // If we have windows, get space info from the first window
    guard !windows.isEmpty,
          let firstWindowId = windows.first?.id else {
      spaceIds = []
      spaceIndexes = []
      isOnAllSpaces = false
      return
    }

    // Get all spaces this window appears on
    let cgWindowId = CGWindowID(firstWindowId)
    spaceIds = cgWindowId.spaces()

    // Map space IDs to UI indices
    spaceIndexes = spaceIds.compactMap { spaceId in
      Spaces.idsAndIndexes.first { $0.0 == spaceId }?.1
    }

    // Window appears on multiple spaces (or all spaces) if count > 1
    isOnAllSpaces = spaceIds.count > 1

    // Log space information for debugging cross-space switching
    NSLog("AltSwitch: [updateSpaceInfo] \(localizedName) window \(cgWindowId) - spaceIds: \(spaceIds), currentSpace: \(Spaces.currentSpaceId), isOnAllSpaces: \(isOnAllSpaces)")
  }

  /// Check if this app's window is on the current space
  var isOnCurrentSpace: Bool {
    guard !windows.isEmpty else { return true }
    return isOnAllSpaces || spaceIds.contains(Spaces.currentSpaceId)
  }

  /// Check if this app's window is on a specific screen
  func isOnScreen(_ screen: NSScreen) -> Bool {
    guard !windows.isEmpty,
          let firstWindowId = windows.first?.id else {
      return true
    }

    let cgWindowId = CGWindowID(firstWindowId)
    return cgWindowId.isOnScreen(screen)
  }
}

// MARK: - Preview Support

// These static factory methods provide mock data for SwiftUI #Preview macros in Xcode Canvas.
// Used by: AppListView.swift, AppRowView.swift
// DO NOT DELETE: Essential for UI development and testing without running real applications.
extension AppInfo {
  static var preview: AppInfo {
    AppInfo(
      bundleIdentifier: "com.example.app",
      localizedName: "Example App",
      processIdentifier: 1234,
      icon: NSImage(systemSymbolName: "app.fill", accessibilityDescription: "App icon")
        ?? NSImage(),
      isActive: true,
      isHidden: false,
      windows: [],
      lastActivationTime: Date()
    )
  }

  static var previewList: [AppInfo] {
    let now = Date()
    return [
      AppInfo(
        bundleIdentifier: "com.example.app1",
        localizedName: "Example App 1",
        processIdentifier: 1234,
        icon: NSImage(systemSymbolName: "app.fill", accessibilityDescription: "App icon")
          ?? NSImage(),
        isActive: true,
        isHidden: false,
        windows: [],
        lastActivationTime: now
      ),
      AppInfo(
        bundleIdentifier: "com.example.app2",
        localizedName: "Example App 2",
        processIdentifier: 1235,
        icon: NSImage(systemSymbolName: "app.fill", accessibilityDescription: "App icon")
          ?? NSImage(),
        isActive: false,
        isHidden: false,
        windows: [],
        lastActivationTime: now.addingTimeInterval(-60)  // 1 minute ago
      ),
      AppInfo(
        bundleIdentifier: "com.example.app3",
        localizedName: "Example App 3",
        processIdentifier: 1236,
        icon: NSImage(systemSymbolName: "app.fill", accessibilityDescription: "App icon")
          ?? NSImage(),
        isActive: false,
        isHidden: true,
        windows: [],
        lastActivationTime: now.addingTimeInterval(-300)  // 5 minutes ago
      ),
    ]
  }
}
