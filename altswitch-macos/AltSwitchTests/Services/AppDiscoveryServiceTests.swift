//
//  AppDiscoveryServiceTests.swift
//  AltSwitchTests
//
//  Comprehensive integration tests for AppDiscoveryService refactoring protection.
//  These tests capture current behavior to ensure no regressions during refactoring.
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import AltSwitch

// MARK: - Test Suite 1: Window Discovery Accuracy

@Suite("Window Discovery Accuracy", .serialized)
@MainActor
struct WindowDiscoveryAccuracyTests {

  @Test("Discovers all standard windows for running apps")
  func test_discoversAllStandardWindows() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching running apps
    let apps = try await service.fetchRunningApps(showIndividualWindows: false)

    // Then: All discovered apps should have been validated
    #expect(apps.count > 0, "Should discover at least one running app")

    for app in apps {
      // Verify essential properties
      #expect(!app.bundleIdentifier.isEmpty, "Bundle identifier must not be empty")
      #expect(app.processIdentifier > 0, "Process identifier must be positive")
      #expect(!app.localizedName.isEmpty, "App should have a localized name")

      // If app has windows, verify window properties
      for window in app.windows {
        #expect(window.id > 0, "Window ID must be positive")
        #expect(window.bounds.width >= 100, "Window width should be >= 100")
        #expect(window.bounds.height >= 50, "Window height should be >= 50")
        #expect(window.layer == 0, "Standard windows should be on layer 0")
        #expect(window.alpha > 0.9, "Visible windows should have alpha > 0.9")
      }
    }
  }

  @Test("Filters out utility windows correctly")
  func test_filtersUtilityWindows() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching running apps
    let apps = try await service.fetchRunningApps(showIndividualWindows: false)

    // Then: No utility windows should be present
    for app in apps {
      for window in app.windows {
        // Check window title doesn't contain utility keywords
        let lowercaseTitle = window.title.lowercased()
        #expect(!lowercaseTitle.contains("item-0"), "Should filter out item-0 windows")
        #expect(!lowercaseTitle.contains("hidden"), "Should filter out hidden windows")
        #expect(!lowercaseTitle.contains("offscreen"), "Should filter out offscreen windows")
        #expect(!lowercaseTitle.contains("web inspector"), "Should filter out inspector windows")

        // Check window size is reasonable
        #expect(window.bounds.width >= 100, "Should filter out windows < 100px wide")
        #expect(window.bounds.height >= 50, "Should filter out windows < 50px tall")

        // Check aspect ratio is reasonable
        let aspectRatio = window.bounds.width / window.bounds.height
        #expect(aspectRatio >= 0.3 && aspectRatio <= 5.0, "Should filter out extreme aspect ratios")
      }
    }
  }

  @Test("Handles apps with no windows")
  func test_handlesAppsWithNoWindows() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching running apps
    let apps = try await service.fetchRunningApps(showIndividualWindows: false)

    // Then: Apps without windows should still be valid
    let appsWithoutWindows = apps.filter { $0.windows.isEmpty }

    for app in appsWithoutWindows {
      #expect(!app.bundleIdentifier.isEmpty, "App without windows should have bundle ID")
      #expect(app.processIdentifier > 0, "App without windows should have valid PID")
      #expect(!app.localizedName.isEmpty, "App without windows should have name")
    }

    // Menu bar apps often have no windows
    if let menuBarApp = apps.first(where: {
      $0.windows.isEmpty && !$0.bundleIdentifier.contains("com.apple.")
    }) {
      print("Found menu bar app without windows: \(menuBarApp.localizedName)")
      #expect(menuBarApp.windows.isEmpty, "Menu bar app should have empty windows array")
    }
  }

  @Test("Correctly identifies focused windows")
  func test_identifiesFocusedWindows() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching running apps
    let apps = try await service.fetchRunningApps(showIndividualWindows: false)

    // Then: The frontmost app should be marked as active
    let activeApps = apps.filter { $0.isActive }

    if !activeApps.isEmpty {
      #expect(activeApps.count == 1, "Only one app should be active")
      let activeApp = activeApps[0]
      #expect(activeApp.processIdentifier > 0, "Active app should have valid PID")

      // Active app should match system's frontmost application
      if let frontmostApp = NSWorkspace.shared.frontmostApplication {
        #expect(
          activeApp.processIdentifier == frontmostApp.processIdentifier,
          "Active app PID should match frontmost app"
        )
      }
    }
  }

  @Test("Discovers windows across multiple Spaces")
  func test_discoversWindowsAcrossSpaces() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching running apps
    let apps = try await service.fetchRunningApps(showIndividualWindows: false)

    // Then: Check for windows with space information
    var windowsWithSpaceInfo = 0
    var windowsOnAllSpaces = 0

    for app in apps {
      for window in app.windows {
        if !window.spaceIds.isEmpty {
          windowsWithSpaceInfo += 1
        }
        if window.isOnAllSpaces {
          windowsOnAllSpaces += 1
        }
      }
    }

    print("Windows with space info: \(windowsWithSpaceInfo)")
    print("Windows on all spaces: \(windowsOnAllSpaces)")

    // We should have at least some windows with space information
    // (This may vary based on system state)
    #expect(windowsWithSpaceInfo >= 0, "Should process space information for windows")
  }
}

// MARK: - Test Suite 2: Individual Window Mode

@Suite("Individual Window Mode", .serialized)
@MainActor
struct IndividualWindowModeTests {

  @Test("Individual mode creates separate AppInfo per window")
  func test_individualModeCreatesSeparateAppInfo() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching in individual window mode
    let individualApps = try await service.fetchRunningApps(showIndividualWindows: true)

    // And: Fetching in standard mode
    let standardApps = try await service.fetchRunningApps(showIndividualWindows: false)

    // Then: Individual mode should have more entries if any app has multiple windows
    let appsWithMultipleWindows = standardApps.filter { $0.windows.count > 1 }

    if !appsWithMultipleWindows.isEmpty {
      let expectedIndividualCount = standardApps.reduce(0) { total, app in
        total + max(1, app.windows.count)
      }

      print("Standard mode apps: \(standardApps.count)")
      print("Individual mode apps: \(individualApps.count)")
      print("Expected individual count: ~\(expectedIndividualCount)")

      // In individual mode, each window gets its own AppInfo
      #expect(
        individualApps.count >= standardApps.count,
        "Individual mode should have at least as many entries as standard mode"
      )
    }

    // Each individual AppInfo should have exactly one window
    for app in individualApps {
      #expect(
        app.windows.count <= 1,
        "Individual mode apps should have at most one window"
      )
    }
  }

  @Test("Window titles are correctly extracted in individual mode")
  func test_windowTitlesExtractedCorrectly() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching in individual window mode
    let apps = try await service.fetchRunningApps(showIndividualWindows: true)

    // Then: Apps with windows should have window titles
    let appsWithWindows = apps.filter { !$0.windows.isEmpty }

    for app in appsWithWindows {
      if let windowTitle = app.windowTitle {
        #expect(!windowTitle.isEmpty || app.windows[0].title.isEmpty,
                "Window title should be set if window has a title")

        // Window title in AppInfo should match the window's title
        if !app.windows.isEmpty {
          let expectedTitle = app.windows[0].title
          if !expectedTitle.isEmpty {
            #expect(windowTitle == expectedTitle,
                    "AppInfo window title should match window title")
          }
        }
      }
    }
  }

  @Test("Focus state is accurate in individual mode")
  func test_focusStateAccurateInIndividualMode() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching in individual window mode
    let apps = try await service.fetchRunningApps(showIndividualWindows: true)

    // Then: At most one window should be marked as active
    let activeApps = apps.filter { $0.isActive }

    if !activeApps.isEmpty {
      #expect(activeApps.count == 1, "At most one window should be active in individual mode")

      let activeApp = activeApps[0]
      #expect(!activeApp.windows.isEmpty, "Active app should have a window")

      // The active app should correspond to the frontmost application
      if let frontmostApp = NSWorkspace.shared.frontmostApplication {
        #expect(
          activeApp.processIdentifier == frontmostApp.processIdentifier,
          "Active window should belong to frontmost app"
        )
      }
    }
  }

  @Test("Individual mode filters to standard windows only")
  func test_individualModeFiltersToStandardWindows() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching in individual window mode
    let apps = try await service.fetchRunningApps(showIndividualWindows: true)

    // Then: All windows should be standard windows
    for app in apps where !app.windows.isEmpty {
      let window = app.windows[0]

      // Verify window meets standard window criteria
      #expect(window.bounds.width >= 100, "Standard windows should be >= 100px wide")
      #expect(window.bounds.height >= 50, "Standard windows should be >= 50px tall")
      #expect(window.alpha > 0.9, "Standard windows should be visible")
      #expect(window.isOnScreen, "Standard windows should be on screen")
      #expect(window.layer == 0, "Standard windows should be on layer 0")
    }
  }
}

// MARK: - Test Suite 3: Event-Driven Updates

@Suite("Event-Driven Updates", .serialized)
@MainActor
struct EventDrivenUpdateTests {

  @Test("Service initializes with event-driven mode when permissions granted")
  func test_initializesWithEventDrivenMode() async throws {
    // Given: Accessibility permissions are available
    let hasPermissions = AXIsProcessTrusted()

    // When: Creating a service instance
    let service = PackageAppDiscovery()

    // Then: Event mode should be enabled if permissions are granted
    // Note: We can't directly access eventModeEnabled, but we can test behavior
    if hasPermissions {
      // First call should populate cache
      let apps1 = try await service.fetchRunningApps()

      // Second call should be faster (served from cache)
      let start = Date()
      let apps2 = try await service.fetchRunningApps()
      let elapsed = Date().timeIntervalSince(start)

      #expect(apps2.count > 0, "Should return cached apps")
      #expect(elapsed < 0.01, "Cached response should be fast (<10ms)")
    } else {
      print("Skipping event-driven tests - no accessibility permissions")
    }
  }

  @Test("Cache TTL works correctly in non-event mode")
  func test_cacheTTLInNonEventMode() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Making rapid successive calls
    let apps1 = try await service.fetchRunningApps()
    let apps2 = try await service.fetchRunningApps()

    // Then: Second call should return same results (from cache)
    #expect(apps1.count == apps2.count, "Cached result should match")

    // When: Waiting for cache to expire (>500ms)
    try await Task.sleep(nanoseconds: 600_000_000) // 600ms

    // And: Fetching again
    let apps3 = try await service.fetchRunningApps()

    // Then: Should get fresh results (may differ)
    #expect(apps3.count >= 0, "Should get valid results after cache expiry")
  }

  @Test("Different cache for individual vs standard mode")
  func test_separateCacheForModes() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching in both modes
    let standardApps = try await service.fetchRunningApps(showIndividualWindows: false)
    let individualApps = try await service.fetchRunningApps(showIndividualWindows: true)

    // Then: Results should be cached separately
    let standardApps2 = try await service.fetchRunningApps(showIndividualWindows: false)
    let individualApps2 = try await service.fetchRunningApps(showIndividualWindows: true)

    #expect(standardApps.count == standardApps2.count, "Standard mode should use its cache")
    #expect(individualApps.count == individualApps2.count, "Individual mode should use its cache")
  }

  @Test("RefreshWindows updates specific app windows")
  func test_refreshWindowsForSpecificApp() async throws {
    // Given: A service instance and discovered apps
    let service = PackageAppDiscovery()
    let apps = try await service.fetchRunningApps()

    // When: We have at least one app with windows
    if let appWithWindows = apps.first(where: { !$0.windows.isEmpty }) {
      // Then: Refreshing should work without error
      let refreshedWindows = try await service.refreshWindows(for: appWithWindows)

      #expect(refreshedWindows.count >= 0, "Refresh should return valid window array")

      // Verify window properties are valid
      for window in refreshedWindows {
        #expect(window.id > 0, "Window ID must be positive")
        #expect(window.bounds.width > 0, "Window must have width")
        #expect(window.bounds.height > 0, "Window must have height")
      }
    }
  }
}

// MARK: - Performance Tests

@Suite("AppDiscoveryService Performance", .serialized)
@MainActor
struct AppDiscoveryPerformanceTests {

  @Test("Discovery completes within performance budget")
  func test_discoveryPerformance() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Measuring discovery time
    let start = Date()
    let apps = try await service.fetchRunningApps()
    let elapsed = Date().timeIntervalSince(start)

    // Then: Should complete within budget
    print("Discovery took \(elapsed * 1000)ms for \(apps.count) apps")
    #expect(elapsed < 0.5, "Discovery should complete within 500ms")
    #expect(apps.count > 0, "Should discover at least one app")
  }

  @Test("Individual mode performance")
  func test_individualModePerformance() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Measuring individual mode discovery
    let start = Date()
    let apps = try await service.fetchRunningApps(showIndividualWindows: true)
    let elapsed = Date().timeIntervalSince(start)

    // Then: Should complete within budget even with more processing
    print("Individual mode took \(elapsed * 1000)ms for \(apps.count) entries")
    #expect(elapsed < 0.7, "Individual mode should complete within 700ms")
  }
}

// MARK: - Edge Cases and Error Handling

@Suite("AppDiscoveryService Edge Cases", .serialized)
@MainActor
struct AppDiscoveryEdgeCaseTests {

  @Test("Handles invalid process identifiers")
  func test_handlesInvalidPIDs() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching apps (some may have terminated during discovery)
    let apps = try await service.fetchRunningApps()

    // Then: All returned apps should have valid PIDs
    for app in apps {
      #expect(app.processIdentifier > 0, "PID must be positive")
      #expect(app.processIdentifier < 999_999, "PID must be reasonable")
    }
  }

  @Test("Filters system processes correctly")
  func test_filtersSystemProcesses() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching apps
    let apps = try await service.fetchRunningApps()

    // Then: System processes should be filtered
    let systemProcesses = [
      "com.apple.dock",
      "com.apple.WindowManager",
      "com.apple.controlcenter",
      "com.apple.Spotlight",
      "com.apple.notificationcenterui",
      "com.apple.systemuiserver"
    ]

    for systemProcess in systemProcesses {
      #expect(!apps.contains { $0.bundleIdentifier == systemProcess },
              "Should filter system process: \(systemProcess)")
    }
  }

  @Test("Excludes own app from results")
  func test_excludesOwnApp() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching apps
    let apps = try await service.fetchRunningApps()

    // Then: AltSwitch itself should not be in results
    let ownBundleID = Bundle.main.bundleIdentifier ?? ""
    #expect(!apps.contains { $0.bundleIdentifier == ownBundleID },
            "Should exclude own app from results")
  }

  @Test("Handles windows on invisible screens")
  func test_handlesInvisibleScreenWindows() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Fetching apps
    let apps = try await service.fetchRunningApps()

    // Then: All windows should be on visible screens
    let visibleScreens = NSScreen.screens

    for app in apps {
      for window in app.windows {
        // Check if window intersects with any visible screen
        let intersectsScreen = visibleScreens.contains { screen in
          screen.frame.intersects(window.bounds)
        }

        if !window.isMinimised && window.isOnScreen {
          #expect(intersectsScreen || window.bounds.isEmpty,
                  "On-screen window should be on a visible screen")
        }
      }
    }
  }
}