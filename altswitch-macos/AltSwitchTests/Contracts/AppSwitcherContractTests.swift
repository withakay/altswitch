//
//  AppSwitcherContractTests.swift
//  AltSwitchTests
//
//  Contract tests for the AppSwitcherService using deterministic stubs.
//

import AppKit
import Foundation
import Testing

@testable import AltSwitch

@Suite("App Switcher Contract")
struct AppSwitcherContractTests {

  @Test("Switch to app records foreground request")
  @MainActor
  func testSwitchToApp() async throws {
    let stub = StubAppSwitcher()
    let app = TestFixtures.app(bundleIdentifier: "com.apple.finder", name: "Finder", pid: 1001)

    try await stub.switchTo(app)
    let switched = stub.switchedBundles()
    #expect(switched == [app.bundleIdentifier], "Finder should be recorded as switched")
  }

  @Test("Switch handles accessibility permission denial")
  @MainActor
  func testAccessibilityDenied() async throws {
    @MainActor
    struct MockDeniedSwitcher: AppSwitcherProtocol {
      func switchTo(_ app: AppInfo) async throws { throw AppSwitchError.accessibilityDenied }
      func bringToFront(_ app: AppInfo) async throws { throw AppSwitchError.accessibilityDenied }
      func unhide(_ app: AppInfo) async throws { throw AppSwitchError.accessibilityDenied }
    }

    let service = MockDeniedSwitcher()
    let app = TestFixtures.app(bundleIdentifier: "test.app", name: "Test", pid: 1_234)

    do {
      try await service.switchTo(app)
      Issue.record("Expected accessibility denied error")
    } catch AppSwitchError.accessibilityDenied {
      #expect(true)
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("Switch completes within performance threshold")
  @MainActor
  func testSwitchPerformance() async throws {
    let stub = StubAppSwitcher()
    let app = TestFixtures.app(bundleIdentifier: "com.apple.finder", name: "Finder", pid: 1001)

    let startTime = Date()
    try await stub.switchTo(app)
    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 0.1, "Stubbed switch should be well under 100ms")
  }

  @Test("Switch handles non-existent app")
  @MainActor
  func testSwitchToNonExistentApp() async throws {
    let stub = StubAppSwitcher(errors: [
      "com.does.not.exist.anywhere.12345": AppSwitchError.appNotFound
    ])
    let app = TestFixtures.app(
      bundleIdentifier: "com.does.not.exist.anywhere.12345", name: "Ghost App", pid: 99999)

    do {
      try await stub.switchTo(app)
      Issue.record("Expected not found error")
    } catch AppSwitchError.appNotFound {
      #expect(true, "Should throw app not found error")
    } catch {
      Issue.record("Unexpected error: \(error)")
    }
  }

  @Test("Multiple switch operations in sequence")
  @MainActor
  func testSequentialSwitching() async throws {
    let stub = StubAppSwitcher()
    let finder = TestFixtures.app(bundleIdentifier: "com.apple.finder", name: "Finder", pid: 1001)
    let safari = TestFixtures.app(bundleIdentifier: "com.apple.Safari", name: "Safari", pid: 1002)

    try await stub.switchTo(finder)
    try await stub.switchTo(safari)
    try await stub.switchTo(finder)

    let switched = stub.switchedBundles()
    #expect(
      switched == [finder.bundleIdentifier, safari.bundleIdentifier, finder.bundleIdentifier])
  }

  @Test("Error messages are descriptive")
  func testErrorDescriptions() {
    let accessError = AppSwitchError.accessibilityDenied
    #expect(accessError.errorDescription != nil)
    #expect(accessError.recoverySuggestion != nil)

    let notFoundError = AppSwitchError.appNotFound
    #expect(notFoundError.errorDescription != nil)

    let timeoutError = AppSwitchError.timeout
    #expect(timeoutError.errorDescription != nil)
  }

  @Test("Accessibility permissions can be checked")
  @MainActor
  func testAccessibilityPermissions() {
    let stubWithPermissions = StubAppSwitcher(hasPermissions: true)
    #expect(
      stubWithPermissions.hasAccessibilityPermissions(), "Should report permissions available")

    let stubWithoutPermissions = StubAppSwitcher(hasPermissions: false)
    #expect(
      !stubWithoutPermissions.hasAccessibilityPermissions(), "Should report permissions unavailable"
    )
  }

  @Test("Permission request returns correct result")
  @MainActor
  func testPermissionRequest() async {
    let stubWithPermissions = StubAppSwitcher(hasPermissions: true)
    let granted = await stubWithPermissions.requestAccessibilityPermissions()
    #expect(granted, "Should grant permissions when available")

    let stubWithoutPermissions = StubAppSwitcher(hasPermissions: false)
    let denied = await stubWithoutPermissions.requestAccessibilityPermissions()
    #expect(!denied, "Should deny permissions when unavailable")
  }
}

@MainActor
private final class StubAppSwitcher: AppSwitcherProtocol {
  private var switched: [String] = []
  private let errors: [String: Error]
  private let hasPermissions: Bool

  init(errors: [String: Error] = [:], hasPermissions: Bool = true) {
    self.errors = errors
    self.hasPermissions = hasPermissions
  }

  @MainActor
  func switchTo(_ app: AppInfo) async throws {
    if let error = errors[app.bundleIdentifier] {
      throw error
    }
    switched.append(app.bundleIdentifier)
  }

  func bringToFront(_ app: AppInfo) async throws {
    if let error = errors[app.bundleIdentifier] {
      throw error
    }
  }

  func unhide(_ app: AppInfo) async throws {
    if let error = errors[app.bundleIdentifier] {
      throw error
    }
  }

  func switchedBundles() -> [String] {
    switched
  }

  func hasAccessibilityPermissions() -> Bool {
    hasPermissions
  }

  func requestAccessibilityPermissions() async -> Bool {
    hasPermissions
  }
}
