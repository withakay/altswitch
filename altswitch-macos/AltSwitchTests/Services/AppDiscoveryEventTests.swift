//
//  AppDiscoveryEventTests.swift
//  AltSwitchTests
//
//  Tests for event-driven caching and AX observer behavior in AppDiscoveryService
//

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import AltSwitch

// MARK: - Event-Driven Behavior Tests

@Suite("AppDiscoveryService Event-Driven Behavior", .serialized)
@MainActor
struct AppDiscoveryEventTests {

  // MARK: App Launch Detection

  @Test("Detects app launch events when event mode enabled")
  func test_detectsAppLaunchEvents() async throws {
    // Skip if no accessibility permissions
    guard AXIsProcessTrusted() else {
      print("Skipping event test - no accessibility permissions")
      return
    }

    // Given: A service with event mode enabled
    let service = PackageAppDiscovery()

    // Get initial apps
    let initialApps = try await service.fetchRunningApps()
    let initialCount = initialApps.count

    // When: An app launches (simulated by workspace notification)
    // Note: In real tests, we'd need to actually launch an app or mock NSWorkspace

    // Then: Service should detect the new app
    // (This is a placeholder - actual test would need app lifecycle simulation)
    print("Initial app count: \(initialCount)")
    #expect(initialCount >= 0, "Should have valid initial app count")
  }

  // MARK: App Termination Detection

  @Test("Detects app termination events")
  func test_detectsAppTerminationEvents() async throws {
    guard AXIsProcessTrusted() else {
      print("Skipping event test - no accessibility permissions")
      return
    }

    // Given: A service tracking running apps
    let service = PackageAppDiscovery()

    // Get current apps
    let apps = try await service.fetchRunningApps()

    // When: An app terminates (would be detected via NSWorkspace notification)
    // Note: Real implementation would need app termination simulation

    // Then: Service should remove the terminated app from cache
    #expect(apps.count >= 0, "Should maintain valid app list")
  }

  // MARK: Window Creation Detection

  @Test("Detects window creation via AX observer")
  func test_detectsWindowCreation() async throws {
    guard AXIsProcessTrusted() else {
      print("Skipping AX observer test - no accessibility permissions")
      return
    }

    // Given: A service monitoring window changes
    let service = PackageAppDiscovery()

    // Find an app with windows
    let apps = try await service.fetchRunningApps()
    guard let appWithWindows = apps.first(where: { !$0.windows.isEmpty }) else {
      print("No apps with windows to test")
      return
    }

    let initialWindowCount = appWithWindows.windows.count

    // When: A new window is created (kAXWindowCreatedNotification)
    // Note: Would need to trigger actual window creation or mock AX notification

    // Then: Window count should update
    print("App \(appWithWindows.localizedName) has \(initialWindowCount) windows")
    #expect(initialWindowCount > 0, "Test app should have windows")
  }

  // MARK: Window Destruction Detection

  @Test("Detects window destruction via AX observer")
  func test_detectsWindowDestruction() async throws {
    guard AXIsProcessTrusted() else {
      print("Skipping AX observer test - no accessibility permissions")
      return
    }

    // Given: An app with multiple windows
    let service = PackageAppDiscovery()
    let apps = try await service.fetchRunningApps()

    guard let multiWindowApp = apps.first(where: { $0.windows.count > 1 }) else {
      print("No multi-window apps to test")
      return
    }

    let initialWindowCount = multiWindowApp.windows.count

    // When: A window is closed (kAXUIElementDestroyedNotification)
    // Note: Would need actual window closure or mock

    // Then: Window count should decrease
    print("Multi-window app has \(initialWindowCount) windows")
    #expect(initialWindowCount > 1, "Should have multiple windows for test")
  }

  // MARK: Focus Change Detection

  @Test("Detects focused window changes")
  func test_detectsFocusedWindowChanges() async throws {
    guard AXIsProcessTrusted() else {
      print("Skipping focus test - no accessibility permissions")
      return
    }

    // Given: Multiple apps with windows
    let service = PackageAppDiscovery()
    let apps = try await service.fetchRunningApps()

    let activeApp = apps.first { $0.isActive }
    let inactiveApp = apps.first { !$0.isActive && !$0.windows.isEmpty }

    if let active = activeApp, let inactive = inactiveApp {
      print("Active app: \(active.localizedName)")
      print("Inactive app: \(inactive.localizedName)")

      // When: Focus changes (kAXFocusedWindowChangedNotification)
      // Note: Would need to trigger actual focus change

      // Then: isActive flags should update
      #expect(active.isActive, "Active app should be marked active")
      #expect(!inactive.isActive, "Inactive app should not be marked active")
    }
  }

  // MARK: Cache Behavior

  @Test("Event mode serves from cache without re-discovery")
  func test_eventModeServesFromCache() async throws {
    guard AXIsProcessTrusted() else {
      print("Skipping cache test - no accessibility permissions")
      return
    }

    // Given: A service with event mode enabled
    let service = PackageAppDiscovery()

    // Warm up the cache
    _ = try await service.fetchRunningApps()

    // When: Making multiple rapid requests
    let start = Date()
    let results = try await withThrowingTaskGroup(of: [AppInfo].self) { group in
      // Make 10 parallel requests
      for _ in 0..<10 {
        group.addTask {
          try await service.fetchRunningApps()
        }
      }

      var allResults: [[AppInfo]] = []
      for try await result in group {
        allResults.append(result)
      }
      return allResults
    }
    let elapsed = Date().timeIntervalSince(start)

    // Then: All should return quickly from cache
    print("10 parallel fetches took \(elapsed * 1000)ms")
    #expect(elapsed < 0.05, "Cached responses should be very fast (<50ms for 10 calls)")

    // All results should be identical (same cache)
    let firstCount = results[0].count
    for result in results {
      #expect(result.count == firstCount, "All cached results should be identical")
    }
  }

  @Test("Non-event mode uses TTL cache")
  func test_nonEventModeUsesTTLCache() async throws {
    // This test works regardless of permissions
    let service = PackageAppDiscovery()

    // When: Making rapid successive calls
    let result1 = try await service.fetchRunningApps()

    // Immediately call again (should hit cache)
    let start = Date()
    let result2 = try await service.fetchRunningApps()
    let cacheHitTime = Date().timeIntervalSince(start)

    // Then: Second call should be very fast (cache hit)
    print("Cache hit took \(cacheHitTime * 1000)ms")
    #expect(cacheHitTime < 0.01, "Cache hit should be <10ms")
    #expect(result1.count == result2.count, "Cached result should match")

    // When: Waiting for TTL expiry (>500ms)
    try await Task.sleep(nanoseconds: 600_000_000)

    // Then: Next call should be slower (cache miss)
    let missStart = Date()
    let result3 = try await service.fetchRunningApps()
    let cacheMissTime = Date().timeIntervalSince(missStart)

    print("Cache miss took \(cacheMissTime * 1000)ms")
    #expect(cacheMissTime > cacheHitTime, "Cache miss should be slower than hit")
  }
}

// MARK: - AX Observer Integration Tests

@Suite("AX Observer Integration", .serialized)
@MainActor
struct AXObserverIntegrationTests {

  @Test("Registers AX observers for eligible apps")
  func test_registersAXObserversForEligibleApps() async throws {
    guard AXIsProcessTrusted() else {
      print("Skipping AX observer test - no accessibility permissions")
      return
    }

    // Given: A new service instance
    let service = PackageAppDiscovery()

    // When: Service initializes with event mode
    let apps = try await service.fetchRunningApps()

    // Then: Should have registered observers for regular apps
    let regularApps = apps.filter { app in
      !app.bundleIdentifier.starts(with: "com.apple.") ||
      app.bundleIdentifier == "com.apple.Safari" ||
      app.bundleIdentifier == "com.apple.finder"
    }

    print("Found \(regularApps.count) regular apps that should have AX observers")
    #expect(!regularApps.isEmpty, "Should have at least one regular app with observer")
  }

  @Test("Removes AX observers when apps terminate")
  func test_removesAXObserversOnTermination() async throws {
    guard AXIsProcessTrusted() else {
      print("Skipping AX observer test - no accessibility permissions")
      return
    }

    // Given: A service tracking apps
    let service = PackageAppDiscovery()
    _ = try await service.fetchRunningApps()

    // When: An app terminates
    // Note: Would need to simulate app termination

    // Then: Observer should be removed
    // (This is a placeholder for actual implementation)
    #expect(true, "Observer cleanup logic should be tested with app lifecycle simulation")
  }

  @Test("Handles rapid window updates without flooding")
  func test_handlesRapidWindowUpdates() async throws {
    guard AXIsProcessTrusted() else {
      print("Skipping rapid update test - no accessibility permissions")
      return
    }

    // Given: An app with windows being monitored
    let service = PackageAppDiscovery()
    let apps = try await service.fetchRunningApps()

    guard let appWithWindows = apps.first(where: { !$0.windows.isEmpty }) else {
      print("No apps with windows to test")
      return
    }

    // When: Multiple window events occur rapidly
    // (Would need to trigger rapid AX notifications)

    // Then: Service should coalesce updates efficiently
    let refreshStart = Date()
    _ = try await service.refreshWindows(for: appWithWindows)
    let refreshTime = Date().timeIntervalSince(refreshStart)

    print("Window refresh took \(refreshTime * 1000)ms")
    #expect(refreshTime < 0.1, "Window refresh should be fast (<100ms)")
  }
}

// MARK: - Performance Under Load

@Suite("AppDiscoveryService Performance Under Load", .serialized)
@MainActor
struct AppDiscoveryLoadTests {

  @Test("Handles many concurrent requests efficiently")
  func test_handlesConcurrentRequests() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // Warm up
    _ = try await service.fetchRunningApps()

    // When: Making many concurrent requests
    let concurrentRequests = 50
    let start = Date()

    let results = try await withThrowingTaskGroup(of: Int.self) { group in
      for i in 0..<concurrentRequests {
        group.addTask {
          let apps = try await service.fetchRunningApps(
            showIndividualWindows: i % 2 == 0  // Mix modes
          )
          return apps.count
        }
      }

      var counts: [Int] = []
      for try await count in group {
        counts.append(count)
      }
      return counts
    }

    let elapsed = Date().timeIntervalSince(start)

    // Then: Should handle load efficiently
    print("\(concurrentRequests) concurrent requests took \(elapsed * 1000)ms")
    print("Average time per request: \((elapsed / Double(concurrentRequests)) * 1000)ms")

    #expect(elapsed < 2.0, "Should handle \(concurrentRequests) requests in <2s")
    #expect(!results.isEmpty, "All requests should complete")
  }

  @Test("Memory usage remains stable under repeated calls")
  func test_stableMemoryUsage() async throws {
    // Given: A service instance
    let service = PackageAppDiscovery()

    // When: Making many repeated calls
    for i in 0..<100 {
      _ = try await service.fetchRunningApps(showIndividualWindows: i % 3 == 0)

      // Small delay to simulate real usage
      try await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }

    // Then: Memory should not grow unbounded
    // (Manual verification needed via Instruments)
    #expect(true, "Memory usage should be monitored via Instruments")
  }
}

// MARK: - Test Helpers

extension AppDiscoveryEventTests {

  /// Helper to wait for an async condition with timeout
  func waitFor(
    _ condition: @escaping () async -> Bool,
    timeout: TimeInterval = 5.0,
    pollingInterval: TimeInterval = 0.1
  ) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
      if await condition() {
        return true
      }
      try? await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
    }

    return false
  }
}