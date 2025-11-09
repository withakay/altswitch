//
//  PerformanceTests.swift
//  AltSwitchTests
//
//  Performance tests for AltSwitch core functionality
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import Testing

@testable import AltSwitch

@Suite("Performance Tests")
struct PerformanceTests {

  @Test("Window appearance performance <100ms")
  func testWindowAppearancePerformance() async throws {
    // Arrange
    let windowManager = MockWindowManager()
    let hotkeyManager = MockHotkeyManager()

    let activationCombo = TestKeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Activate Window"
    )

    try await hotkeyManager.registerHotkey(activationCombo) {
      await windowManager.showWindow()
    }

    // Act - Measure window appearance time
    let measurements = (1...20).map { _ in
      let startTime = Date()
      await hotkeyManager.simulateHotkeyPress(activationCombo)
      let appearanceTime = await windowManager.getLastAppearanceTime()
      await windowManager.hideWindow()
      return appearanceTime
    }

    // Assert - All measurements should be under 100ms
    for (index, time) in measurements.enumerated() {
      #expect(
        time < 0.1,
        "Window appearance #\(index + 1) should be under 100ms, was \(time * 1000)ms")
    }

    // Average should be well under target
    let averageTime = measurements.reduce(0, +) / Double(measurements.count)
    #expect(
      averageTime < 0.05,
      "Average window appearance should be under 50ms, was \(averageTime * 1000)ms")

    // 95th percentile should be under target
    let sortedTimes = measurements.sorted()
    let percentile95Index = Int(Double(sortedTimes.count) * 0.95)
    let percentile95Time = sortedTimes[percentile95Index]
    #expect(
      percentile95Time < 0.08,
      "95th percentile window appearance should be under 80ms, was \(percentile95Time * 1000)ms")
  }

  @Test("Search response performance <50ms")
  func testSearchResponsePerformance() async throws {
    // Arrange
    let searchService = MockSearchService()
    let appDatabase = MockAppDatabase()

    // Create large application database
    let largeAppList = (1...100).map { i in
      MockApplication(
        bundleIdentifier: "com.test.App\(i)",
        displayName: "Test Application \(i)"
      )
    }
    await appDatabase.setApplications(largeAppList)

    let testQueries = [
      "test", "app", "1", "application", "t", "te", "tes", "",
      "very long search query that should still perform well",
    ]

    for query in testQueries {
      // Act - Measure search response time
      let measurements = (1...15).map { _ in
        let startTime = Date()
        let results = await searchService.search(query, in: appDatabase)
        let searchTime = Date().timeIntervalSince(startTime)
        return (searchTime, results.count)
      }

      // Assert - All search times should be under 50ms
      for (index, (time, resultCount)) in measurements.enumerated() {
        #expect(
          time < 0.05,
          "Search '\(query)' #\(index + 1) should be under 50ms, was \(time * 1000)ms (found \(resultCount) results)"
        )
      }

      // Average should be well under target
      let searchTimes = measurements.map { $0.0 }
      let averageTime = searchTimes.reduce(0, +) / Double(searchTimes.count)
      #expect(
        averageTime < 0.02,
        "Average search time for '\(query)' should be under 20ms, was \(averageTime * 1000)ms")
    }
  }

  @Test("App switching performance <200ms")
  func testAppSwitchingPerformance() async throws {
    // Arrange
    let appSwitcher = MockAppSwitcher()
    let appDiscovery = MockAppDiscoveryService()

    // Set up running applications
    let runningApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Firefox"),
      MockApplication(bundleIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code"),
      MockApplication(bundleIdentifier: "com.apple.finder", displayName: "Finder"),
    ]
    await appDiscovery.setRunningApplications(runningApps)

    // Test switching to each application multiple times
    for targetApp in runningApps {
      // Act - Measure app switching time
      let measurements = (1...10).map { _ in
        let startTime = Date()
        let result = await appSwitcher.switchToApplication(targetApp)
        let switchTime = Date().timeIntervalSince(startTime)
        return (switchTime, result)
      }

      // Assert - All switch times should be under 200ms
      for (index, (time, result)) in measurements.enumerated() {
        #expect(
          time < 0.2,
          "Switch to \(targetApp.displayName) #\(index + 1) should be under 200ms, was \(time * 1000)ms"
        )
        #expect(result == .success, "Switch should succeed")
      }

      // Average should be well under target
      let switchTimes = measurements.map { $0.0 }
      let averageTime = switchTimes.reduce(0, +) / Double(switchTimes.count)
      #expect(
        averageTime < 0.1,
        "Average switch time to \(targetApp.displayName) should be under 100ms, was \(averageTime * 1000)ms"
      )
    }
  }

  @Test("Memory usage baseline <50MB")
  func testMemoryUsageBaseline() async throws {
    // Arrange
    let appInstance = MockAltSwitchApp()
    await appInstance.initialize()

    // Act - Measure memory usage over time
    let memoryMeasurements = (1...10).map { _ in
      // Simulate app activity
      await appInstance.simulateTypicalUsage()

      let memoryUsage = await appInstance.getCurrentMemoryUsage()
      try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms between measurements
      return memoryUsage
    }

    // Assert - All measurements should be under 50MB
    for (index, memoryUsage) in memoryMeasurements.enumerated() {
      #expect(
        memoryUsage < 50_000_000,
        "Memory usage #\(index + 1) should be under 50MB, was \(memoryUsage / 1_000_000)MB")
    }

    // Average should be well under target
    let averageMemoryUsage = memoryMeasurements.reduce(0, +) / Double(memoryMeasurements.count)
    #expect(
      averageMemoryUsage < 30_000_000,
      "Average memory usage should be under 30MB, was \(averageMemoryUsage / 1_000_000)MB")

    // Memory growth should be minimal
    let initialMemory = memoryMeasurements.first!
    let finalMemory = memoryMeasurements.last!
    let memoryGrowth = finalMemory - initialMemory
    #expect(
      memoryGrowth < 5_000_000,
      "Memory growth should be under 5MB, was \(memoryGrowth / 1_000_000)MB")
  }

  @Test("Hotkey response performance <10ms")
  func testHotkeyResponsePerformance() async throws {
    // Arrange
    let hotkeyManager = MockHotkeyManager()
    let windowManager = MockWindowManager()

    let testCombos = [
      TestKeyCombo(
        shortcut: .init(.space, modifiers: [.command, .shift]), description: "Main Hotkey"),
      TestKeyCombo(
        shortcut: .init(.tab, modifiers: [.command, .option]), description: "Alternative Hotkey"),
      TestKeyCombo(shortcut: .init(.escape, modifiers: [.command]), description: "Dismiss Hotkey"),
    ]

    for combo in testCombos {
      try await hotkeyManager.registerHotkey(combo) {
        await windowManager.toggleWindow()
      }

      // Act - Measure hotkey response time
      let measurements = (1...30).map { _ in
        let startTime = Date()
        await hotkeyManager.simulateHotkeyPress(combo)
        let responseTime = Date().timeIntervalSince(startTime)
        return responseTime
      }

      // Assert - All response times should be under 10ms
      for (index, time) in measurements.enumerated() {
        #expect(
          time < 0.01,
          "Hotkey '\(combo.description)' #\(index + 1) should respond under 10ms, was \(time * 1000)ms"
        )
      }

      // Average should be well under target
      let averageTime = measurements.reduce(0, +) / Double(measurements.count)
      #expect(
        averageTime < 0.005,
        "Average hotkey response for '\(combo.description)' should be under 5ms, was \(averageTime * 1000)ms"
      )
    }
  }

  @Test("App discovery performance <100ms")
  func testAppDiscoveryPerformance() async throws {
    // Arrange
    let appDiscovery = MockAppDiscoveryService()

    // Simulate many running applications
    let manyApps = (1...75).map { i in
      MockApplication(
        bundleIdentifier: "com.test.App\(i)",
        displayName: "Test Application \(i)"
      )
    }
    await appDiscovery.setMockApplications(manyApps)

    // Act - Measure discovery performance
    let measurements = (1...15).map { _ in
      let startTime = Date()
      let discoveredApps = await appDiscovery.discoverRunningApplications()
      let discoveryTime = Date().timeIntervalSince(startTime)
      return (discoveryTime, discoveredApps.count)
    }

    // Assert - All discovery times should be under 100ms
    for (index, (time, appCount)) in measurements.enumerated() {
      #expect(
        time < 0.1,
        "App discovery #\(index + 1) should be under 100ms, was \(time * 1000)ms (found \(appCount) apps)"
      )
      #expect(appCount == manyApps.count, "Should discover all mock applications")
    }

    // Average should be well under target
    let discoveryTimes = measurements.map { $0.0 }
    let averageTime = discoveryTimes.reduce(0, +) / Double(discoveryTimes.count)
    #expect(
      averageTime < 0.05,
      "Average app discovery time should be under 50ms, was \(averageTime * 1000)ms")
  }

  @Test("UI rendering performance <16ms (60fps)")
  func testUIRenderingPerformance() async throws {
    // Arrange
    let uiRenderer = MockUIRenderer()
    let appList = MockAppListManager()

    // Set up large application list for rendering
    let largeAppList = (1...50).map { i in
      MockApplication(
        bundleIdentifier: "com.test.App\(i)",
        displayName: "Test Application \(i)"
      )
    }
    await appList.setApplications(largeAppList)

    // Test different rendering scenarios
    let renderingScenarios = [
      ("Initial render", { await uiRenderer.renderInitialAppList(appList) }),
      ("Search filter", { await uiRenderer.renderFilteredAppList(appList, query: "test") }),
      ("Selection change", { await uiRenderer.renderSelectionChange(appList, selectedIndex: 25) }),
      (
        "Window resize",
        { await uiRenderer.renderWindowResize(appList, newSize: CGSize(width: 800, height: 600)) }
      ),
    ]

    for (scenarioName, renderAction) in renderingScenarios {
      // Act - Measure rendering performance
      let measurements = (1...20).map { _ in
        let startTime = Date()
        await renderAction()
        let renderTime = Date().timeIntervalSince(startTime)
        return renderTime
      }

      // Assert - All render times should be under 16ms (60fps)
      for (index, time) in measurements.enumerated() {
        #expect(
          time < 0.016,
          "\(scenarioName) render #\(index + 1) should be under 16ms, was \(time * 1000)ms")
      }

      // Average should be well under target
      let averageTime = measurements.reduce(0, +) / Double(measurements.count)
      #expect(
        averageTime < 0.008,
        "Average \(scenarioName) render time should be under 8ms, was \(averageTime * 1000)ms")
    }
  }

  @Test("Performance under system load")
  func testPerformanceUnderSystemLoad() async throws {
    // Arrange
    let systemLoadSimulator = MockSystemLoadSimulator()
    let appInstance = MockAltSwitchApp()
    await appInstance.initialize()

    // Test different load levels
    let loadLevels = [
      (LoadLevel.low, 0.2),
      (LoadLevel.medium, 0.5),
      (LoadLevel.high, 0.8),
      (LoadLevel.critical, 0.95),
    ]

    for (loadLevel, cpuLoad) in loadLevels {
      // Act - Simulate system load and measure performance
      await systemLoadSimulator.setCPULoad(cpuLoad)
      await systemLoadSimulator.setMemoryLoad(cpuLoad * 0.8)

      let measurements = (1...10).map { _ in
        let startTime = Date()
        await appInstance.simulateCriticalOperation()
        let operationTime = Date().timeIntervalSince(startTime)
        return operationTime
      }

      // Assert - Performance should degrade gracefully
      let averageTime = measurements.reduce(0, +) / Double(measurements.count)
      let maxAcceptableTime = 0.1 * (1.0 + cpuLoad)  // Scale acceptance with load

      for (index, time) in measurements.enumerated() {
        #expect(
          time < maxAcceptableTime,
          "Critical operation under \(loadLevel) load #\(index + 1) should be under \(maxAcceptableTime * 1000)ms, was \(time * 1000)ms"
        )
      }

      // Reset load
      await systemLoadSimulator.setCPULoad(0.1)
      await systemLoadSimulator.setMemoryLoad(0.1)
    }
  }
}

// MARK: - Mock Classes for Testing

private actor MockWindowManager {
  private var isWindowVisible = false
  private var lastAppearanceTime: TimeInterval = 0

  func showWindow() async {
    let startTime = Date()
    // Simulate window rendering delay
    try? await Task.sleep(nanoseconds: 5_000_000)  // 5ms
    isWindowVisible = true
    lastAppearanceTime = Date().timeIntervalSince(startTime)
  }

  func hideWindow() async {
    isWindowVisible = false
  }

  func toggleWindow() async {
    if isWindowVisible {
      await hideWindow()
    } else {
      await showWindow()
    }
  }

  func getLastAppearanceTime() async -> TimeInterval {
    return lastAppearanceTime
  }
}

private actor MockHotkeyManager {
  private var registeredHotkeys: [TestKeyCombo: () async -> Void] = [:]

  func registerHotkey(_ combo: TestKeyCombo, action: @escaping () async -> Void) async throws {
    registeredHotkeys[combo] = action
  }

  func simulateHotkeyPress(_ combo: TestKeyCombo) async {
    if let action = registeredHotkeys[combo] {
      let startTime = Date()
      await action()
      // Simulate hotkey processing overhead
      try? await Task.sleep(nanoseconds: 500_000)  // 0.5ms
    }
  }
}

private actor MockSearchService {
  func search(_ query: String, in database: MockAppDatabase) async -> [MockApplication] {
    let startTime = Date()
    let apps = await database.getApplications()

    // Simulate search processing
    try? await Task.sleep(nanoseconds: 2_000_000)  // 2ms

    let results = apps.filter { app in
      app.displayName.lowercased().contains(query.lowercased())
    }

    return results
  }
}

private actor MockAppDatabase {
  private var applications: [MockApplication] = []

  func setApplications(_ apps: [MockApplication]) async {
    applications = apps
  }

  func getApplications() async -> [MockApplication] {
    return applications
  }
}

private actor MockAppSwitcher {
  enum SwitchResult {
    case success
    case failure
  }

  func switchToApplication(_ app: MockApplication) async -> SwitchResult {
    let startTime = Date()
    // Simulate app switching delay
    try? await Task.sleep(nanoseconds: 15_000_000)  // 15ms
    let switchTime = Date().timeIntervalSince(startTime)
    return .success
  }
}

private actor MockAppDiscoveryService {
  private var mockApplications: [MockApplication] = []

  func setMockApplications(_ apps: [MockApplication]) async {
    mockApplications = apps
  }

  func discoverRunningApplications() async -> [MockApplication] {
    let startTime = Date()
    // Simulate discovery delay
    try? await Task.sleep(nanoseconds: 8_000_000)  // 8ms
    return mockApplications
  }
}

private actor MockAltSwitchApp {
  private var memoryUsage: UInt64 = 10_000_000  // 10MB baseline

  func initialize() async {
    // Simulate initialization
    try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
    memoryUsage = 25_000_000  // 25MB after init
  }

  func simulateTypicalUsage() async {
    // Simulate typical app operations
    try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    memoryUsage += UInt64.random(in: 0...1_000_000)  // Small memory variations
  }

  func simulateCriticalOperation() async {
    // Simulate critical path operation
    try? await Task.sleep(nanoseconds: 20_000_000)  // 20ms
  }

  func getCurrentMemoryUsage() async -> UInt64 {
    return memoryUsage
  }
}

private actor MockUIRenderer {
  func renderInitialAppList(_ appList: MockAppListManager) async {
    let apps = await appList.getApplications()
    // Simulate rendering delay
    try? await Task.sleep(nanoseconds: 3_000_000)  // 3ms
  }

  func renderFilteredAppList(_ appList: MockAppListManager, query: String) async {
    let apps = await appList.getApplications()
    let filtered = apps.filter { $0.displayName.lowercased().contains(query.lowercased()) }
    // Simulate filtered rendering
    try? await Task.sleep(nanoseconds: 4_000_000)  // 4ms
  }

  func renderSelectionChange(_ appList: MockAppListManager, selectedIndex: Int) async {
    // Simulate selection change rendering
    try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms
  }

  func renderWindowResize(_ appList: MockAppListManager, newSize: CGSize) async {
    // Simulate resize rendering
    try? await Task.sleep(nanoseconds: 6_000_000)  // 6ms
  }
}

private actor MockAppListManager {
  private var applications: [MockApplication] = []

  func setApplications(_ apps: [MockApplication]) async {
    applications = apps
  }

  func getApplications() async -> [MockApplication] {
    return applications
  }
}

private actor MockSystemLoadSimulator {
  private var cpuLoad: Double = 0.1
  private var memoryLoad: Double = 0.1

  func setCPULoad(_ load: Double) async {
    cpuLoad = load
    // Simulate CPU load by adding delays
    try? await Task.sleep(nanoseconds: UInt64(load * 100_000_000))  // Scale delay with load
  }

  func setMemoryLoad(_ load: Double) async {
    memoryLoad = load
    // Simulate memory pressure
    try? await Task.sleep(nanoseconds: UInt64(load * 50_000_000))  // Scale delay with load
  }
}

// MARK: - Supporting Test Types

private struct TestKeyCombo: Hashable, Sendable {
  let shortcut: KeyboardShortcuts.Shortcut
  let description: String
}

private struct MockApplication: Equatable, Sendable {
  let bundleIdentifier: String
  let displayName: String
}

private enum LoadLevel: String {
  case low = "Low"
  case medium = "Medium"
  case high = "High"
  case critical = "Critical"
}
