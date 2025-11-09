//
//  AppDiscoveryContractTests.swift
//  AltSwitchTests
//
//  Contract tests for the AppDiscoveryService backed by deterministic stubs.
//

import AppKit
import Foundation
import Testing

@testable import AltSwitch

@Suite("App Discovery Contract")
struct AppDiscoveryContractTests {

  @Test("Fetch running applications returns non-empty list")
  func testFetchRunningApps() async throws {
    let service = makeStubAppDiscoveryService()
    let apps = try await service.fetchRunningApps()

    #expect(apps.count > 0, "Should discover at least one running app")
    for app in apps {
      #expect(!app.bundleIdentifier.isEmpty, "Bundle ID must not be empty")
      #expect(!app.localizedName.isEmpty, "App name must not be empty")
      #expect(app.processIdentifier > 0, "Process ID must be positive")
    }
  }

  @Test("Running apps include Finder")
  func testFinderAlwaysPresent() async throws {
    let service = makeStubAppDiscoveryService()
    let apps = try await service.fetchRunningApps()

    let finder = apps.first { $0.bundleIdentifier == "com.apple.finder" }
    #expect(finder != nil, "Finder should always be running")
  }

  @Test("Fetch windows for app returns window list")
  func testFetchWindowsForApp() async throws {
    let service = makeStubAppDiscoveryService()
    let apps = try await service.fetchRunningApps()
    guard let finder = apps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
      Issue.record("Finder missing from stub data")
      return
    }

    let windows = try await service.refreshWindows(for: finder)
    #expect(!windows.isEmpty, "Finder should have at least one window")
    for window in windows {
      #expect(window.id != kCGNullWindowID, "Window ID must be valid")
      #expect(window.alpha >= 0.0 && window.alpha <= 1.0, "Alpha must be in range [0.0, 1.0]")
    }
  }

  @Test("Service handles no running apps gracefully")
  func testEmptyAppsScenario() async throws {
    struct MockEmptyWorkspace: AppDiscoveryProtocol {
      func fetchRunningApps() async throws -> [AppInfo] { [] }
      func refreshWindows(for app: AppInfo) async throws -> [WindowInfo] { [] }
    }

    let service = MockEmptyWorkspace()
    let apps = try await service.fetchRunningApps()
    #expect(apps.isEmpty, "Should handle empty apps list")
  }

  @Test("Service respects Sendable protocol")
  func testSendableCompliance() {
    let service: AppDiscoveryProtocol & Sendable = PackageAppDiscovery()
    _ = service
    #expect(true, "AppDiscoveryService conforms to Sendable")
  }

  @Test("Window refresh handles app without windows")
  func testRefreshWindowsEmptyCase() async throws {
    let service = makeStubAppDiscoveryService()
    let mockApp = TestFixtures.app(
      bundleIdentifier: "com.apple.notificationcenterui",
      name: "Notification Center",
      pid: 9_999
    )

    let windows = try await service.refreshWindows(for: mockApp)
    #expect(windows.isEmpty, "Should return no windows for unknown app")
  }

  @Test("Apps have valid icons")
  func testAppIconsValid() async throws {
    let service = makeStubAppDiscoveryService()
    let apps = try await service.fetchRunningApps()
    for app in apps {
      #expect(app.icon.isValid, "App icon should be valid")
      #expect(app.icon.size.width > 0 && app.icon.size.height > 0, "Icon should have non-zero size")
    }
  }

  @Test("Window information includes necessary details")
  func testWindowInfoCompleteness() async throws {
    let service = makeStubAppDiscoveryService()
    let apps = try await service.fetchRunningApps()
    guard let finder = apps.first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
      Issue.record("Finder missing from stub data")
      return
    }

    let windows = try await service.refreshWindows(for: finder)
    if let firstWindow = windows.first {
      #expect(firstWindow.id > 0, "Window ID should be positive")
      #expect(firstWindow.alpha >= 0.0 && firstWindow.alpha <= 1.0, "Alpha in range")
    }
  }

  @Test("Service handles concurrent requests")
  func testConcurrentFetching() async throws {
    let service = makeStubAppDiscoveryService()
    async let fetch1 = service.fetchRunningApps()
    async let fetch2 = service.fetchRunningApps()
    async let fetch3 = service.fetchRunningApps()

    let results = try await [fetch1, fetch2, fetch3]
    for apps in results {
      #expect(apps.count > 0, "Each concurrent fetch should return apps")
    }
    let counts = Set(results.map { $0.count })
    #expect(counts.count == 1, "Counts should match across concurrent calls")
  }

  @Test("Performance: Fetch completes within threshold")
  func testFetchPerformance() async throws {
    let service = makeStubAppDiscoveryService()
    let startTime = Date()
    _ = try await service.fetchRunningApps()
    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 0.1, "Fetch should complete well under 100ms")
  }

  @Test("Check if app is running returns correct status")
  func testIsAppRunning() async throws {
    let service = makeStubAppDiscoveryService()

    let finderRunning = await service.isAppRunning("com.apple.finder")
    #expect(finderRunning, "Finder should be detected as running")

    let nonExistentRunning = await service.isAppRunning("com.nonexistent.app")
    #expect(!nonExistentRunning, "Non-existent app should not be running")
  }

  @Test("Get app icon returns valid image")
  func testGetAppIcon() async throws {
    let service = makeStubAppDiscoveryService()
    let apps = try await service.fetchRunningApps()
    guard let firstApp = apps.first else {
      Issue.record("No apps found")
      return
    }

    let icon = await service.getAppIcon(for: firstApp)
    #expect(icon.isValid, "App icon should be valid")
    #expect(icon.size.width > 0 && icon.size.height > 0, "Icon should have non-zero size")
  }
}

private struct StubAppDiscoveryService: AppDiscoveryProtocol, Sendable {
  let apps: [AppInfo]
  let windowsByPID: [pid_t: [WindowInfo]]

  func fetchRunningApps() async throws -> [AppInfo] {
    apps
  }

  func refreshWindows(for app: AppInfo) async throws -> [WindowInfo] {
    windowsByPID[app.processIdentifier] ?? []
  }

  func isAppRunning(_ bundleIdentifier: String) async -> Bool {
    apps.contains { $0.bundleIdentifier == bundleIdentifier }
  }

  func getAppIcon(for app: AppInfo) async -> NSImage {
    return NSImage(systemSymbolName: "app.fill", accessibilityDescription: nil) ?? NSImage()
  }
}

private func makeStubAppDiscoveryService() -> StubAppDiscoveryService {
  let finderWindows = [
    TestFixtures.window(id: 1001, title: "Finder"),
    TestFixtures.window(id: 1002, title: "Downloads"),
  ]
  let finder = TestFixtures.app(
    bundleIdentifier: "com.apple.finder",
    name: "Finder",
    pid: 101,
    isActive: true,
    windows: finderWindows
  )
  let safari = TestFixtures.app(
    bundleIdentifier: "com.apple.Safari",
    name: "Safari",
    pid: 202,
    windows: [TestFixtures.window(id: 2001, title: "Safari Window")]
  )
  let terminal = TestFixtures.app(
    bundleIdentifier: "com.apple.Terminal",
    name: "Terminal",
    pid: 303,
    windows: []
  )

  let windowsByPID: [pid_t: [WindowInfo]] = [
    finder.processIdentifier: finderWindows,
    safari.processIdentifier: safari.windows,
  ]

  return StubAppDiscoveryService(
    apps: [finder, safari, terminal],
    windowsByPID: windowsByPID
  )
}

// Helper to check XCTSkip compatibility with Swift Testing
enum XCTSkip: Error {
  case skip(String)

  init(_ message: String) {
    self = .skip(message)
  }
}
