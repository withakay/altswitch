//
//  AppSwitchingTests.swift
//  AltSwitchTests
//
//  Integration tests for application switching functionality
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import Testing

@testable import AltSwitch

@Suite("App Switching Integration")
struct AppSwitchingTests {

  @Test("Switch to running application")
  func testSwitchToRunningApplication() async throws {
    // Arrange
    let appSwitcher = MockAppSwitcher()
    let appDiscovery = MockAppDiscoveryService()
    let windowManager = MockWindowManager()

    // Set up running applications
    let runningApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Firefox"),
    ]
    await appDiscovery.setRunningApplications(runningApps)

    // Act - Switch to Chrome
    let targetApp = runningApps.first { $0.bundleIdentifier == "com.google.Chrome" }!
    let switchResult = await appSwitcher.switchToApplication(targetApp)

    // Assert - Should switch successfully
    #expect(switchResult == .success, "Should successfully switch to Chrome")

    let activatedApp = await appSwitcher.getLastActivatedApplication()
    #expect(
      activatedApp?.bundleIdentifier == "com.google.Chrome",
      "Should have activated Chrome")

    let switchTime = await appSwitcher.getLastSwitchTime()
    #expect(switchTime < 0.2, "App switch should complete within 200ms")
  }

  @Test("Launch and switch to non-running application")
  func testLaunchAndSwitchToNonRunningApplication() async throws {
    // Arrange
    let appSwitcher = MockAppSwitcher()
    let appDiscovery = MockAppDiscoveryService()
    let appLauncher = MockAppLauncher()

    // Set up running applications (target app is not running)
    let runningApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
    ]
    await appDiscovery.setRunningApplications(runningApps)

    // Target app that's not running
    let targetApp = MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Firefox")

    // Act - Switch to non-running app
    let switchResult = await appSwitcher.switchToApplication(targetApp)

    // Assert - Should launch and switch
    #expect(switchResult == .launchedAndSwitched, "Should launch Firefox and switch to it")

    let launchedApp = await appLauncher.getLastLaunchedApplication()
    #expect(
      launchedApp?.bundleIdentifier == "com.mozilla.firefox",
      "Should have launched Firefox")

    let activatedApp = await appSwitcher.getLastActivatedApplication()
    #expect(
      activatedApp?.bundleIdentifier == "com.mozilla.firefox",
      "Should have activated Firefox")

    let launchTime = await appLauncher.getLastLaunchTime()
    #expect(launchTime < 2.0, "App launch should complete within 2 seconds")
  }

  @Test("Switch to application with multiple windows")
  func testSwitchToApplicationWithMultipleWindows() async throws {
    // Arrange
    let appSwitcher = MockAppSwitcher()
    let windowManager = MockWindowManager()
    let appDiscovery = MockAppDiscoveryService()

    // Set up app with multiple windows
    let targetApp = MockApplication(
      bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
    let windows = [
      MockWindow(id: "window1", title: "Google - Search", app: targetApp),
      MockWindow(id: "window2", title: "GitHub - Code", app: targetApp),
      MockWindow(id: "window3", title: "Stack Overflow - Questions", app: targetApp),
    ]
    await windowManager.setWindowsForApplication(targetApp, windows: windows)

    let runningApps = [targetApp]
    await appDiscovery.setRunningApplications(runningApps)

    // Act - Switch to Chrome
    let switchResult = await appSwitcher.switchToApplication(targetApp)

    // Assert - Should switch and bring all windows forward
    #expect(switchResult == .success, "Should successfully switch to Chrome")

    let broughtToFrontWindows = await windowManager.getWindowsBroughtToFront()
    #expect(
      broughtToFrontWindows.count == windows.count,
      "Should bring all Chrome windows to front")

    let activatedApp = await appSwitcher.getLastActivatedApplication()
    #expect(
      activatedApp?.bundleIdentifier == "com.google.Chrome",
      "Should have activated Chrome")
  }

  @Test("Handle application switching failures")
  func testHandleApplicationSwitchingFailures() async throws {
    // Arrange
    let appSwitcher = MockAppSwitcher()
    let appDiscovery = MockAppDiscoveryService()

    // Set up scenario where app exists but can't be activated
    let problematicApp = MockApplication(
      bundleIdentifier: "com.test.Problematic", displayName: "Problematic App")
    await appSwitcher.setAppActivationFailure(for: problematicApp.bundleIdentifier)

    let runningApps = [problematicApp]
    await appDiscovery.setRunningApplications(runningApps)

    // Act - Attempt to switch to problematic app
    let switchResult = await appSwitcher.switchToApplication(problematicApp)

    // Assert - Should handle failure gracefully
    #expect(switchResult == .failure, "Should report failure for problematic app")

    let errorDetails = await appSwitcher.getLastErrorDetails()
    #expect(
      errorDetails?.appBundleId == problematicApp.bundleIdentifier,
      "Error should reference the problematic app")

    // Should not crash or leave system in inconsistent state
    let lastActivatedApp = await appSwitcher.getLastActivatedApplication()
    #expect(lastActivatedApp == nil, "Should not have activated any app after failure")
  }

  @Test("Rapid application switching")
  func testRapidApplicationSwitching() async throws {
    // Arrange
    let appSwitcher = MockAppSwitcher()
    let appDiscovery = MockAppDiscoveryService()

    // Set up multiple applications
    let apps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Firefox"),
      MockApplication(bundleIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code"),
      MockApplication(bundleIdentifier: "com.apple.finder", displayName: "Finder"),
    ]
    await appDiscovery.setRunningApplications(apps)

    // Act - Perform rapid switches
    let switchSequence = [0, 2, 1, 4, 3, 0, 2]  // Safari, Firefox, Chrome, Finder, VSCode, Safari, Firefox
    let startTime = Date()

    for appIndex in switchSequence {
      let targetApp = apps[appIndex]
      let result = await appSwitcher.switchToApplication(targetApp)
      #expect(
        result == .success || result == .launchedAndSwitched,
        "Switch to \(targetApp.displayName) should succeed")
    }

    let totalTime = Date().timeIntervalSince(startTime)

    // Assert - Should handle rapid switching efficiently
    #expect(totalTime < 1.0, "Rapid switching should complete within 1 second")

    let switchHistory = await appSwitcher.getSwitchHistory()
    #expect(
      switchHistory.count == switchSequence.count,
      "Should have recorded all switches")

    // Last activated should be the last in sequence
    let lastActivated = await appSwitcher.getLastActivatedApplication()
    let expectedLastApp = apps[switchSequence.last!]
    #expect(
      lastActivated?.bundleIdentifier == expectedLastApp.bundleIdentifier,
      "Last activated should match sequence")
  }

  @Test("Application switching with minimized windows")
  func testSwitchingWithMinimizedWindows() async throws {
    // Arrange
    let appSwitcher = MockAppSwitcher()
    let windowManager = MockWindowManager()
    let appDiscovery = MockAppDiscoveryService()

    // Set up app with minimized windows
    let targetApp = MockApplication(
      bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
    let minimizedWindows = [
      MockWindow(id: "window1", title: "Google - Search", app: targetApp, isMinimized: true),
      MockWindow(id: "window2", title: "GitHub - Code", app: targetApp, isMinimized: true),
    ]
    await windowManager.setWindowsForApplication(targetApp, windows: minimizedWindows)

    let runningApps = [targetApp]
    await appDiscovery.setRunningApplications(runningApps)

    // Act - Switch to app with minimized windows
    let switchResult = await appSwitcher.switchToApplication(targetApp)

    // Assert - Should restore minimized windows
    #expect(switchResult == .success, "Should successfully switch to Chrome")

    let restoredWindows = await windowManager.getRestoredWindows()
    #expect(
      restoredWindows.count == minimizedWindows.count,
      "Should restore all minimized windows")

    for window in restoredWindows {
      #expect(!window.isMinimized, "Restored window should not be minimized")
    }

    let activatedApp = await appSwitcher.getLastActivatedApplication()
    #expect(
      activatedApp?.bundleIdentifier == "com.google.Chrome",
      "Should have activated Chrome")
  }

  @Test("Application switching preserves window order and state")
  func testSwitchingPreservesWindowState() async throws {
    // Arrange
    let appSwitcher = MockAppSwitcher()
    let windowManager = MockWindowManager()
    let appDiscovery = MockAppDiscoveryService()

    // Set up multiple apps with different window states
    let safariApp = MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari")
    let chromeApp = MockApplication(
      bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")

    let safariWindows = [
      MockWindow(id: "safari1", title: "Apple", app: safariApp, isMinimized: false),
      MockWindow(id: "safari2", title: "Developer", app: safariApp, isMinimized: true),
    ]

    let chromeWindows = [
      MockWindow(id: "chrome1", title: "Google", app: chromeApp, isMinimized: false),
      MockWindow(id: "chrome2", title: "GitHub", app: chromeApp, isMinimized: false),
      MockWindow(id: "chrome3", title: "Stack Overflow", app: chromeApp, isMinimized: true),
    ]

    await windowManager.setWindowsForApplication(safariApp, windows: safariWindows)
    await windowManager.setWindowsForApplication(chromeApp, windows: chromeWindows)

    let runningApps = [safariApp, chromeApp]
    await appDiscovery.setRunningApplications(runningApps)

    // Act - Switch between apps and verify state preservation
    // Switch to Safari
    await appSwitcher.switchToApplication(safariApp)
    let safariStateAfterSwitch = await windowManager.getWindowStates(for: safariApp)

    // Switch to Chrome
    await appSwitcher.switchToApplication(chromeApp)
    let chromeStateAfterSwitch = await windowManager.getWindowStates(for: chromeApp)

    // Switch back to Safari
    await appSwitcher.switchToApplication(safariApp)
    let safariStateAfterReturn = await windowManager.getWindowStates(for: safariApp)

    // Assert - Window states should be preserved
    #expect(
      safariStateAfterSwitch.count == safariWindows.count,
      "Safari should maintain window count")
    #expect(
      chromeStateAfterSwitch.count == chromeWindows.count,
      "Chrome should maintain window count")

    // Minimized states should be preserved
    let safariMinimizedStates = safariStateAfterReturn.map { $0.isMinimized }
    let originalSafariMinimizedStates = safariWindows.map { $0.isMinimized }
    #expect(
      safariMinimizedStates == originalSafariMinimizedStates,
      "Safari minimized states should be preserved")

    let chromeMinimizedStates = chromeStateAfterSwitch.map { $0.isMinimized }
    let originalChromeMinimizedStates = chromeWindows.map { $0.isMinimized }
    #expect(
      chromeMinimizedStates == originalChromeMinimizedStates,
      "Chrome minimized states should be preserved")
  }
}

// MARK: - Mock Classes for Testing

private actor MockAppSwitcher {
  private var lastActivatedApp: MockApplication?
  private var switchHistory: [MockApplication] = []
  private var lastSwitchTime: TimeInterval = 0
  private var lastErrorDetails: SwitchErrorDetails?
  private var activationFailures: Set<String> = []

  enum SwitchResult {
    case success
    case launchedAndSwitched
    case failure
  }

  func switchToApplication(_ app: MockApplication) async -> SwitchResult {
    let startTime = Date()

    // Check for activation failures
    if activationFailures.contains(app.bundleIdentifier) {
      lastErrorDetails = SwitchErrorDetails(
        appBundleId: app.bundleIdentifier, error: "Activation failed")
      return .failure
    }

    // Simulate switching delay
    try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms

    lastActivatedApp = app
    switchHistory.append(app)
    lastSwitchTime = Date().timeIntervalSince(startTime)

    return .success
  }

  func setAppActivationFailure(for bundleId: String) async {
    activationFailures.insert(bundleId)
  }

  func getLastActivatedApplication() async -> MockApplication? {
    return lastActivatedApp
  }

  func getSwitchHistory() async -> [MockApplication] {
    return switchHistory
  }

  func getLastSwitchTime() async -> TimeInterval {
    return lastSwitchTime
  }

  func getLastErrorDetails() async -> SwitchErrorDetails? {
    return lastErrorDetails
  }
}

private actor MockAppDiscoveryService {
  private var runningApplications: [MockApplication] = []

  func setRunningApplications(_ apps: [MockApplication]) async {
    runningApplications = apps
  }

  func getRunningApplications() async -> [MockApplication] {
    return runningApplications
  }
}

private actor MockAppLauncher {
  private var lastLaunchedApp: MockApplication?
  private var lastLaunchTime: TimeInterval = 0

  func launchApplication(_ app: MockApplication) async {
    let startTime = Date()

    // Simulate launch delay
    try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms

    lastLaunchedApp = app
    lastLaunchTime = Date().timeIntervalSince(startTime)
  }

  func getLastLaunchedApplication() async -> MockApplication? {
    return lastLaunchedApp
  }

  func getLastLaunchTime() async -> TimeInterval {
    return lastLaunchTime
  }
}

private actor MockWindowManager {
  private var appWindows: [String: [MockWindow]] = [:]
  private var broughtToFrontWindows: [MockWindow] = []
  private var restoredWindows: [MockWindow] = []

  func setWindowsForApplication(_ app: MockApplication, windows: [MockWindow]) async {
    appWindows[app.bundleIdentifier] = windows
  }

  func getWindowsForApplication(_ app: MockApplication) async -> [MockWindow] {
    return appWindows[app.bundleIdentifier] ?? []
  }

  func bringWindowsToFront(_ windows: [MockWindow]) async {
    broughtToFrontWindows.append(contentsOf: windows)
  }

  func restoreWindows(_ windows: [MockWindow]) async {
    restoredWindows.append(contentsOf: windows)
    // Update window states
    for window in windows {
      if let appWindows = appWindows[window.app.bundleIdentifier],
        let index = appWindows.firstIndex(where: { $0.id == window.id })
      {
        appWindows[window.app.bundleIdentifier]?[index].isMinimized = false
      }
    }
  }

  func getWindowsBroughtToFront() async -> [MockWindow] {
    return broughtToFrontWindows
  }

  func getRestoredWindows() async -> [MockWindow] {
    return restoredWindows
  }

  func getWindowStates(for app: MockApplication) async -> [MockWindow] {
    return appWindows[app.bundleIdentifier] ?? []
  }
}

// MARK: - Supporting Test Types

private struct MockApplication: Equatable, Sendable {
  let bundleIdentifier: String
  let displayName: String
}

private struct MockWindow: Equatable, Sendable {
  let id: String
  let title: String
  let app: MockApplication
  var isMinimized: Bool = false
}

private struct SwitchErrorDetails: Equatable, Sendable {
  let appBundleId: String
  let error: String
}
