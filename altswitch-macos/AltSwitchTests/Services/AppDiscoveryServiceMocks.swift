//
//  AppDiscoveryServiceMocks.swift
//  AltSwitchTests
//
//  Mock implementations and test fixtures for AppDiscoveryService tests
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@testable import AltSwitch

// MARK: - Mock Window Factory

enum MockWindowFactory {

  /// Create a standard window info for testing
  static func standardWindow(
    id: CGWindowID = 1001,
    title: String = "Test Window",
    bounds: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
    alpha: CGFloat = 1.0,
    isOnScreen: Bool = true,
    layer: Int = 0,
    spaceIds: [Int] = []
  ) -> WindowInfo {
    WindowInfo(
      id: id,
      title: title,
      bounds: bounds,
      alpha: alpha,
      isOnScreen: isOnScreen,
      layer: layer,
      isTabbed: false,
      isHidden: false,
      dockLabel: title,
      isFullscreen: false,
      isMinimised: false,
      isOnAllSpaces: false,
      isWindowlessApp: false,
      spaceIds: spaceIds,
      axUiElement: nil,
      application: nil
    )
  }

  /// Create a utility window (should be filtered out)
  static func utilityWindow(
    id: CGWindowID = 2001,
    title: String = "item-0"
  ) -> WindowInfo {
    WindowInfo(
      id: id,
      title: title,
      bounds: CGRect(x: 0, y: 0, width: 50, height: 50),
      alpha: 1.0,
      isOnScreen: true,
      layer: 0,
      isTabbed: false,
      isHidden: false,
      dockLabel: title,
      isFullscreen: false,
      isMinimised: false,
      isOnAllSpaces: false,
      isWindowlessApp: false,
      spaceIds: [],
      axUiElement: nil,
      application: nil
    )
  }

  /// Create a minimized window
  static func minimizedWindow(
    id: CGWindowID = 3001,
    title: String = "Minimized Window"
  ) -> WindowInfo {
    WindowInfo(
      id: id,
      title: title,
      bounds: CGRect(x: 100, y: 100, width: 800, height: 600),
      alpha: 1.0,
      isOnScreen: false,
      layer: 0,
      isTabbed: false,
      isHidden: false,
      dockLabel: title,
      isFullscreen: false,
      isMinimised: true,
      isOnAllSpaces: false,
      isWindowlessApp: false,
      spaceIds: [],
      axUiElement: nil,
      application: nil
    )
  }

  /// Create a fullscreen window
  static func fullscreenWindow(
    id: CGWindowID = 4001,
    title: String = "Fullscreen Window"
  ) -> WindowInfo {
    let screen = NSScreen.main ?? NSScreen.screens[0]
    return WindowInfo(
      id: id,
      title: title,
      bounds: screen.frame,
      alpha: 1.0,
      isOnScreen: true,
      layer: 0,
      isTabbed: false,
      isHidden: false,
      dockLabel: title,
      isFullscreen: true,
      isMinimised: false,
      isOnAllSpaces: false,
      isWindowlessApp: false,
      spaceIds: [],
      axUiElement: nil,
      application: nil
    )
  }
}

// MARK: - Mock App Factory

enum MockAppFactory {

  /// Create a standard app info for testing
  static func standardApp(
    bundleIdentifier: String = "com.test.app",
    localizedName: String = "Test App",
    processIdentifier: pid_t = 1234,
    isActive: Bool = false,
    isHidden: Bool = false,
    windows: [WindowInfo] = []
  ) -> AppInfo {
    AppInfo(
      bundleIdentifier: bundleIdentifier,
      localizedName: localizedName,
      processIdentifier: processIdentifier,
      icon: NSImage(),
      isActive: isActive,
      isHidden: isHidden,
      windows: windows
    )
  }

  /// Create an app with multiple windows
  static func appWithMultipleWindows(
    bundleIdentifier: String = "com.test.multiwindow",
    windowCount: Int = 3
  ) -> AppInfo {
    let windows = (1...windowCount).map { i in
      MockWindowFactory.standardWindow(
        id: CGWindowID(5000 + i),
        title: "Window \(i)"
      )
    }

    return AppInfo(
      bundleIdentifier: bundleIdentifier,
      localizedName: "Multi-Window App",
      processIdentifier: 5678,
      icon: NSImage(),
      isActive: false,
      isHidden: false,
      windows: windows
    )
  }

  /// Create an app for individual window mode
  static func individualWindowApp(
    bundleIdentifier: String = "com.test.individual",
    windowId: CGWindowID = 6001,
    windowTitle: String = "Document.txt"
  ) -> AppInfo {
    let window = MockWindowFactory.standardWindow(
      id: windowId,
      title: windowTitle
    )

    return AppInfo(
      bundleIdentifier: bundleIdentifier,
      localizedName: "Individual Window App",
      processIdentifier: 9012,
      icon: NSImage(),
      isActive: false,
      isHidden: false,
      windows: [window],
      windowTitle: windowTitle
    )
  }
}

// MARK: - Mock AppDiscoveryProtocol

/// Mock implementation of AppDiscoveryProtocol for isolated testing
@MainActor
final class MockAppDiscoveryService: AppDiscoveryProtocol {

  // State tracking
  var fetchRunningAppsCalled = false
  var fetchRunningAppsCallCount = 0
  var lastShowIndividualWindows: Bool?

  var refreshWindowsCalled = false
  var refreshWindowsCallCount = 0
  var lastRefreshedApp: AppInfo?

  // Configurable responses
  var appsToReturn: [AppInfo] = []
  var windowsToReturn: [WindowInfo] = []
  var shouldThrowError = false
  var errorToThrow: Error = AppSwitchError.appNotRunning

  // Simulated delays
  var discoveryDelay: TimeInterval = 0
  var refreshDelay: TimeInterval = 0

  func fetchRunningApps(showIndividualWindows: Bool) async throws -> [AppInfo] {
    fetchRunningAppsCalled = true
    fetchRunningAppsCallCount += 1
    lastShowIndividualWindows = showIndividualWindows

    if shouldThrowError {
      throw errorToThrow
    }

    // Simulate processing delay
    if discoveryDelay > 0 {
      try await Task.sleep(nanoseconds: UInt64(discoveryDelay * 1_000_000_000))
    }

    if showIndividualWindows {
      // In individual mode, create separate AppInfo for each window
      var individualApps: [AppInfo] = []

      for app in appsToReturn {
        if app.windows.isEmpty {
          individualApps.append(app)
        } else {
          for window in app.windows {
            let individualApp = AppInfo(
              bundleIdentifier: app.bundleIdentifier,
              localizedName: app.localizedName,
              processIdentifier: app.processIdentifier,
              icon: app.icon,
              isActive: app.isActive,
              isHidden: app.isHidden,
              windows: [window],
              windowTitle: window.title
            )
            individualApps.append(individualApp)
          }
        }
      }

      return individualApps
    }

    return appsToReturn
  }

  func refreshWindows(for app: AppInfo) async throws -> [WindowInfo] {
    refreshWindowsCalled = true
    refreshWindowsCallCount += 1
    lastRefreshedApp = app

    if shouldThrowError {
      throw errorToThrow
    }

    // Simulate processing delay
    if refreshDelay > 0 {
      try await Task.sleep(nanoseconds: UInt64(refreshDelay * 1_000_000_000))
    }

    return windowsToReturn
  }

  // Test helper methods

  func reset() {
    fetchRunningAppsCalled = false
    fetchRunningAppsCallCount = 0
    lastShowIndividualWindows = nil

    refreshWindowsCalled = false
    refreshWindowsCallCount = 0
    lastRefreshedApp = nil

    appsToReturn = []
    windowsToReturn = []
    shouldThrowError = false
    discoveryDelay = 0
    refreshDelay = 0
  }

  func setupStandardApps() {
    appsToReturn = [
      MockAppFactory.standardApp(
        bundleIdentifier: "com.apple.Safari",
        localizedName: "Safari",
        windows: [MockWindowFactory.standardWindow()]
      ),
      MockAppFactory.appWithMultipleWindows(),
      MockAppFactory.standardApp(
        bundleIdentifier: "com.apple.finder",
        localizedName: "Finder",
        windows: []
      )
    ]
  }
}

// MARK: - Test Assertions

extension MockAppDiscoveryService {

  func assertFetchRunningAppsCalled(
    times: Int = 1,
    withIndividualMode: Bool? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard fetchRunningAppsCalled else {
      Issue.record("fetchRunningApps was not called", sourceLocation: SourceLocation(filePath: "\(file)", line: Int(line)))
      return
    }

    guard fetchRunningAppsCallCount == times else {
      Issue.record(
        "fetchRunningApps was called \(fetchRunningAppsCallCount) times, expected \(times)",
        sourceLocation: SourceLocation(filePath: "\(file)", line: Int(line))
      )
      return
    }

    if let expectedMode = withIndividualMode {
      guard lastShowIndividualWindows == expectedMode else {
        Issue.record(
          "fetchRunningApps was called with showIndividualWindows=\(String(describing: lastShowIndividualWindows)), expected \(expectedMode)",
          sourceLocation: SourceLocation(filePath: "\(file)", line: Int(line))
        )
        return
      }
    }
  }

  func assertRefreshWindowsCalled(
    times: Int = 1,
    forApp expectedApp: AppInfo? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard refreshWindowsCalled else {
      Issue.record("refreshWindows was not called", sourceLocation: SourceLocation(filePath: "\(file)", line: Int(line)))
      return
    }

    guard refreshWindowsCallCount == times else {
      Issue.record(
        "refreshWindows was called \(refreshWindowsCallCount) times, expected \(times)",
        sourceLocation: SourceLocation(filePath: "\(file)", line: Int(line))
      )
      return
    }

    if let expectedApp = expectedApp {
      guard let lastApp = lastRefreshedApp,
            lastApp.bundleIdentifier == expectedApp.bundleIdentifier else {
        Issue.record(
          "refreshWindows was called with wrong app",
          sourceLocation: SourceLocation(filePath: "\(file)", line: Int(line))
        )
        return
      }
    }
  }
}

// MARK: - CGWindow Mock Data

enum MockCGWindowData {

  /// Create mock CGWindow dictionary data
  static func cgWindowDict(
    windowID: CGWindowID = 1001,
    ownerPID: pid_t = 1234,
    title: String = "Test Window",
    bounds: CGRect = CGRect(x: 100, y: 100, width: 800, height: 600),
    layer: Int = 0,
    alpha: Float = 1.0,
    isOnScreen: Bool = true
  ) -> [String: Any] {
    [
      kCGWindowNumber as String: windowID,
      kCGWindowOwnerPID as String: ownerPID,
      kCGWindowName as String: title,
      kCGWindowBounds as String: [
        "X": bounds.origin.x,
        "Y": bounds.origin.y,
        "Width": bounds.size.width,
        "Height": bounds.size.height
      ],
      kCGWindowLayer as String: layer,
      kCGWindowAlpha as String: alpha,
      kCGWindowIsOnscreen as String: isOnScreen
    ]
  }
}