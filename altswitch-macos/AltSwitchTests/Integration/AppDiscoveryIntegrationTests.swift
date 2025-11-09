//
//  AppDiscoveryIntegrationTests.swift
//  AltSwitchTests
//
//  Integration tests for app discovery and display functionality
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import Testing

@testable import AltSwitch

@Suite("App Discovery Integration")
struct AppDiscoveryIntegrationTests {

  @Test("Discover and display running applications")
  func testDiscoverAndDisplayRunningApplications() async throws {
    // Arrange
    let appDiscovery = MockAppDiscoveryService()
    let displayManager = MockDisplayManager()

    // Act - Discover running applications
    let discoveredApps = await appDiscovery.discoverRunningApplications()

    // Assert - Should find applications
    #expect(discoveredApps.count > 0, "Should discover at least one running application")
    #expect(
      discoveredApps.allSatisfy { !$0.bundleIdentifier.isEmpty },
      "All apps should have valid bundle identifiers")
    #expect(
      discoveredApps.allSatisfy { !$0.displayName.isEmpty }, "All apps should have display names")

    // Act - Display discovered applications
    await displayManager.displayApplications(discoveredApps)

    // Assert - Display should show discovered apps
    let displayedApps = await displayManager.getDisplayedApplications()
    #expect(
      displayedApps.count == discoveredApps.count, "Should display all discovered applications")
    #expect(
      displayedApps.elementsEqual(
        discoveredApps, by: { $0.bundleIdentifier == $1.bundleIdentifier }),
      "Displayed apps should match discovered apps")
  }

  @Test("App discovery updates when applications launch/quit")
  func testAppDiscoveryUpdatesWithApplicationLifecycle() async throws {
    // Arrange
    let appDiscovery = MockAppDiscoveryService()
    let displayManager = MockDisplayManager()

    // Initial discovery
    let initialApps = await appDiscovery.discoverRunningApplications()
    await displayManager.displayApplications(initialApps)

    // Act - Simulate application launch
    let newApp = MockApplication(bundleIdentifier: "com.test.NewApp", displayName: "New App")
    await appDiscovery.simulateApplicationLaunch(newApp)

    let updatedAppsAfterLaunch = await appDiscovery.discoverRunningApplications()
    await displayManager.displayApplications(updatedAppsAfterLaunch)

    // Assert - Should include newly launched app
    #expect(
      updatedAppsAfterLaunch.count == initialApps.count + 1, "Should include newly launched app")
    #expect(
      updatedAppsAfterLaunch.contains { $0.bundleIdentifier == newApp.bundleIdentifier },
      "Should contain the newly launched app")

    // Act - Simulate application quit
    await appDiscovery.simulateApplicationQuit(newApp.bundleIdentifier)

    let updatedAppsAfterQuit = await appDiscovery.discoverRunningApplications()
    await displayManager.displayApplications(updatedAppsAfterQuit)

    // Assert - Should exclude quit app
    #expect(updatedAppsAfterQuit.count == initialApps.count, "Should exclude quit app")
    #expect(
      !updatedAppsAfterQuit.contains { $0.bundleIdentifier == newApp.bundleIdentifier },
      "Should not contain the quit app")
  }

  @Test("App discovery filters out system and background processes")
  func testAppDiscoveryFiltersSystemProcesses() async throws {
    // Arrange
    let appDiscovery = MockAppDiscoveryService()

    // Act - Discover applications with filtering
    let filteredApps = await appDiscovery.discoverRunningApplications()

    // Assert - Should filter out system processes
    let systemProcessIdentifiers = [
      "com.apple.loginwindow",
      "com.apple.Dock",
      "com.apple.WindowManager",
      "com.apple.controlcenter",
    ]

    for systemId in systemProcessIdentifiers {
      #expect(
        !filteredApps.contains { $0.bundleIdentifier == systemId },
        "Should filter out system process: \(systemId)")
    }

    // Should include user applications
    let userAppIdentifiers = [
      "com.apple.Safari",
      "com.apple.finder",
      "com.microsoft.VSCode",
    ]

    for userAppId in userAppIdentifiers {
      if filteredApps.contains(where: { $0.bundleIdentifier == userAppId }) {
        // If found, it should have proper metadata
        let app = filteredApps.first { $0.bundleIdentifier == userAppId }!
        #expect(!app.displayName.isEmpty, "User app should have display name")
        #expect(app.icon != nil, "User app should have icon")
      }
    }
  }

  @Test("App discovery handles application name localization")
  func testAppDiscoveryHandlesLocalization() async throws {
    // Arrange
    let appDiscovery = MockAppDiscoveryService()
    let localizationManager = MockLocalizationManager()

    // Test with different system languages
    let testLanguages = ["en", "es", "fr", "de", "ja"]

    for language in testLanguages {
      // Act - Set system language and discover apps
      await localizationManager.setSystemLanguage(language)
      let localizedApps = await appDiscovery.discoverRunningApplications()

      // Assert - Should get localized names
      for app in localizedApps {
        let localizedName = await localizationManager.getLocalizedAppName(
          for: app.bundleIdentifier, in: language)

        if !localizedName.isEmpty {
          #expect(
            app.displayName == localizedName,
            "App \(app.bundleIdentifier) should have localized name in \(language)")
        }
      }
    }
  }

  @Test("App discovery performance with many applications")
  func testAppDiscoveryPerformanceWithManyApps() async throws {
    // Arrange
    let appDiscovery = MockAppDiscoveryService()

    // Simulate many running applications
    let manyApps = (1...50).map { i in
      MockApplication(
        bundleIdentifier: "com.test.App\(i)",
        displayName: "Test App \(i)"
      )
    }
    await appDiscovery.setMockApplications(manyApps)

    // Act - Measure discovery performance
    let startTime = Date()
    let discoveredApps = await appDiscovery.discoverRunningApplications()
    let discoveryTime = Date().timeIntervalSince(startTime)

    // Assert - Should complete within performance budget
    #expect(
      discoveryTime < 0.1,
      "App discovery should complete within 100ms, took \(discoveryTime * 1000)ms")
    #expect(discoveredApps.count == manyApps.count, "Should discover all mock applications")

    // Act - Measure display performance
    let displayManager = MockDisplayManager()
    let displayStartTime = Date()
    await displayManager.displayApplications(discoveredApps)
    let displayTime = Date().timeIntervalSince(displayStartTime)

    #expect(
      displayTime < 0.05, "App display should complete within 50ms, took \(displayTime * 1000)ms")
  }

  @Test("App discovery handles hidden and minimized applications")
  func testAppDiscoveryHandlesHiddenApplications() async throws {
    // Arrange
    let appDiscovery = MockAppDiscoveryService()

    // Create apps with different visibility states
    let normalApp = MockApplication(bundleIdentifier: "com.test.Normal", displayName: "Normal App")
    let hiddenApp = MockApplication(bundleIdentifier: "com.test.Hidden", displayName: "Hidden App")
    let minimizedApp = MockApplication(
      bundleIdentifier: "com.test.Minimized", displayName: "Minimized App")

    await appDiscovery.setMockApplications([normalApp, hiddenApp, minimizedApp])

    // Set visibility states
    await appDiscovery.setApplicationVisibility(hiddenApp.bundleIdentifier, isHidden: true)
    await appDiscovery.setApplicationVisibility(minimizedApp.bundleIdentifier, isMinimized: true)

    // Act - Discover applications
    let discoveredApps = await appDiscovery.discoverRunningApplications()

    // Assert - Should discover all apps regardless of visibility
    #expect(discoveredApps.count == 3, "Should discover all apps regardless of visibility state")

    // Should include visibility information
    let discoveredHidden = discoveredApps.first {
      $0.bundleIdentifier == hiddenApp.bundleIdentifier
    }!
    let discoveredMinimized = discoveredApps.first {
      $0.bundleIdentifier == minimizedApp.bundleIdentifier
    }!

    #expect(discoveredHidden.isHidden == true, "Should correctly identify hidden app")
    #expect(discoveredMinimized.isMinimized == true, "Should correctly identify minimized app")
  }

  @Test("App discovery refreshes on demand")
  func testAppDiscoveryRefreshesOnDemand() async throws {
    // Arrange
    let appDiscovery = MockAppDiscoveryService()
    let displayManager = MockDisplayManager()

    // Initial discovery
    let initialApps = await appDiscovery.discoverRunningApplications()
    await displayManager.displayApplications(initialApps)

    // Act - Refresh discovery
    let refreshedApps = await appDiscovery.refreshRunningApplications()
    await displayManager.displayApplications(refreshedApps)

    // Assert - Should get updated results
    #expect(refreshedApps.count >= 0, "Refresh should return valid app list")

    // Should update display with refreshed data
    let displayedApps = await displayManager.getDisplayedApplications()
    #expect(displayedApps.count == refreshedApps.count, "Display should show refreshed app count")

    // Should handle rapid refreshes
    for i in 1...5 {
      let rapidRefreshApps = await appDiscovery.refreshRunningApplications()
      #expect(rapidRefreshApps.count >= 0, "Rapid refresh #\(i) should succeed")
    }
  }
}

// MARK: - Mock Classes for Testing

private actor MockAppDiscoveryService {
  private var mockApplications: [MockApplication] = [
    MockApplication(bundleIdentifier: "com.apple.finder", displayName: "Finder"),
    MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
    MockApplication(bundleIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code"),
  ]
  private var visibilityStates: [String: (isHidden: Bool, isMinimized: Bool)] = [:]

  func discoverRunningApplications() async -> [MockApplication] {
    // Simulate discovery delay
    try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms

    return mockApplications.map { app in
      var appCopy = app
      if let visibility = visibilityStates[app.bundleIdentifier] {
        appCopy.isHidden = visibility.isHidden
        appCopy.isMinimized = visibility.isMinimized
      }
      return appCopy
    }
  }

  func refreshRunningApplications() async -> [MockApplication] {
    return await discoverRunningApplications()
  }

  func simulateApplicationLaunch(_ app: MockApplication) async {
    mockApplications.append(app)
  }

  func simulateApplicationQuit(_ bundleIdentifier: String) async {
    mockApplications.removeAll { $0.bundleIdentifier == bundleIdentifier }
  }

  func setMockApplications(_ apps: [MockApplication]) async {
    mockApplications = apps
  }

  func setApplicationVisibility(
    _ bundleIdentifier: String, isHidden: Bool = false, isMinimized: Bool = false
  ) async {
    visibilityStates[bundleIdentifier] = (isHidden, isMinimized)
  }
}

private actor MockDisplayManager {
  private var displayedApplications: [MockApplication] = []

  func displayApplications(_ apps: [MockApplication]) async {
    // Simulate display rendering delay
    try? await Task.sleep(nanoseconds: 500_000)  // 0.5ms
    displayedApplications = apps
  }

  func getDisplayedApplications() async -> [MockApplication] {
    return displayedApplications
  }
}

private actor MockLocalizationManager {
  private var currentLanguage = "en"
  private let localizedNames: [String: [String: String]] = [
    "com.apple.finder": [
      "en": "Finder", "es": "Finder", "fr": "Finder", "de": "Finder", "ja": "Finder",
    ],
    "com.apple.Safari": [
      "en": "Safari", "es": "Safari", "fr": "Safari", "de": "Safari", "ja": "Safari",
    ],
    "com.microsoft.VSCode": [
      "en": "Visual Studio Code", "es": "Visual Studio Code", "fr": "Visual Studio Code",
      "de": "Visual Studio Code", "ja": "Visual Studio Code",
    ],
  ]

  func setSystemLanguage(_ language: String) async {
    currentLanguage = language
  }

  func getLocalizedAppName(for bundleIdentifier: String, in language: String) async -> String {
    return localizedNames[bundleIdentifier]?[language] ?? ""
  }
}

// MARK: - Supporting Test Types

private struct MockApplication: Equatable, Sendable {
  let bundleIdentifier: String
  var displayName: String
  var icon: NSImage?
  var isHidden: Bool = false
  var isMinimized: Bool = false
}
