//
//  HotkeyPerformanceTests.swift
//  AltSwitchTests
//
//  Performance tests for hotkey registration ensuring <100ms response time
//  Includes stress testing, memory validation, and benchmark reporting
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

/// Performance test suite for hotkey registration operations
@Suite("Hotkey Performance Tests")
struct HotkeyPerformanceTests {

  // MARK: - Performance Constants

  private static let maxRegistrationTime: TimeInterval = 0.1  // 100ms
  private static let maxConcurrentRegistrations = 10
  private static let stressTestIterations = 100
  private static let memoryThresholdMB = 50.0

  // MARK: - Basic Performance Tests

  @Test("Hotkey registration completes within 100ms")
  func testHotkeyRegistrationPerformance() async throws {
    let hotkeyManager = MockHotkeyManager()
    let combo = KeyCombo.defaultShowHide()

    let startTime = CFAbsoluteTimeGetCurrent()

    try await hotkeyManager.register(combo) {}

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

    #expect(
      elapsed < Self.maxRegistrationTime,
      "Hotkey registration took \(elapsed * 1000)ms, expected < \(Self.maxRegistrationTime * 1000)ms"
    )
  }

  @Test("Hotkey unregistration completes within 100ms")
  func testHotkeyUnregistrationPerformance() async throws {
    let hotkeyManager = MockHotkeyManager()
    let combo = KeyCombo.defaultShowHide()

    // Register first
    try await hotkeyManager.register(combo) {}

    let startTime = CFAbsoluteTimeGetCurrent()

    await hotkeyManager.unregister(combo)

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

    #expect(
      elapsed < Self.maxRegistrationTime,
      "Hotkey unregistration took \(elapsed * 1000)ms, expected < \(Self.maxRegistrationTime * 1000)ms"
    )
  }

  @Test("Hotkey validation completes within 10ms")
  func testHotkeyValidationPerformance() async throws {
    let combo = KeyCombo.defaultShowHide()

    let startTime = CFAbsoluteTimeGetCurrent()

    // Perform validation operations
    _ = combo.isValid
    _ = combo.hasSystemConflict
    _ = combo.displayString
    _ = combo.accessibilityDescription

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

    #expect(
      elapsed < 0.01,  // 10ms
      "Hotkey validation took \(elapsed * 1000)ms, expected < 10ms")
  }

  // MARK: - Concurrent Registration Tests

  @Test("Multiple concurrent hotkey registrations complete within performance limits")
  func testConcurrentHotkeyRegistrations() async throws {
    let hotkeyManager = MockHotkeyManager()

    // Create different key combinations
    let combos = [
      KeyCombo(shortcut: .init(.f13, modifiers: [.command]), description: "Test 1"),
      KeyCombo(shortcut: .init(.f14, modifiers: [.command]), description: "Test 2"),
      KeyCombo(shortcut: .init(.f15, modifiers: [.command]), description: "Test 3"),
      KeyCombo(shortcut: .init(.f16, modifiers: [.command]), description: "Test 4"),
      KeyCombo(shortcut: .init(.f17, modifiers: [.command]), description: "Test 5"),
    ]

    let startTime = CFAbsoluteTimeGetCurrent()

    // Register all hotkeys concurrently
    try await withThrowingTaskGroup(of: Void.self) { group in
      for combo in combos {
        group.addTask {
          try await hotkeyManager.register(combo) {}
        }
      }

      for try await _ in group {}
    }

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

    #expect(
      elapsed < Self.maxRegistrationTime * 2,  // Allow 2x time for concurrent operations
      "Concurrent hotkey registrations took \(elapsed * 1000)ms, expected < \(Self.maxRegistrationTime * 2 * 1000)ms"
    )

    // Verify all registrations succeeded
    for combo in combos {
      #expect(
        await hotkeyManager.isRegistered(combo),
        "Hotkey \(combo.displayString) should be registered")
    }
  }

  @Test("Hotkey registration with conflict detection performs within limits")
  func testConflictDetectionPerformance() async throws {
    let hotkeyManager = MockHotkeyManager()
    let errorHandler = await HotkeyErrorHandler()

    // Register a hotkey first
    let existingCombo = KeyCombo.defaultShowHide()
    try await hotkeyManager.register(existingCombo) {}

    // Try to register conflicting hotkey
    let conflictingCombo = KeyCombo.defaultShowHide()  // Same as existing

    let startTime = CFAbsoluteTimeGetCurrent()

    do {
      try await hotkeyManager.register(conflictingCombo) {}
      #expect(Bool(false), "Should have thrown conflict error")
    } catch {
      await errorHandler.handleError(error, for: conflictingCombo)
    }

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

    #expect(
      elapsed < Self.maxRegistrationTime,
      "Conflict detection took \(elapsed * 1000)ms, expected < \(Self.maxRegistrationTime * 1000)ms"
    )

    // Verify error was handled
    #expect(await errorHandler.currentError != nil, "Error should be present after conflict")
  }

  // MARK: - Stress Tests

  @Test("Repeated hotkey registration/unregistration stress test")
  func testRepeatedRegistrationStress() async throws {
    let hotkeyManager = MockHotkeyManager()
    let combo = KeyCombo(shortcut: .init(.f18, modifiers: [.command]), description: "Stress Test")

    var totalTime: TimeInterval = 0
    var maxTime: TimeInterval = 0
    var minTime: TimeInterval = .greatestFiniteMagnitude

    for iteration in 0..<Self.stressTestIterations {
      let startTime = CFAbsoluteTimeGetCurrent()

      // Register and immediately unregister
      try await hotkeyManager.register(combo) {}
      await hotkeyManager.unregister(combo)

      let elapsed = CFAbsoluteTimeGetCurrent() - startTime
      totalTime += elapsed
      maxTime = max(maxTime, elapsed)
      minTime = min(minTime, elapsed)

      // Check individual operation doesn't exceed threshold
      #expect(
        elapsed < Self.maxRegistrationTime * 2,
        "Iteration \(iteration) took \(elapsed * 1000)ms, expected < \(Self.maxRegistrationTime * 2 * 1000)ms"
      )
    }

    let averageTime = totalTime / Double(Self.stressTestIterations)

    print("Stress Test Results:")
    print("  Average time: \(averageTime * 1000)ms")
    print("  Max time: \(maxTime * 1000)ms")
    print("  Min time: \(minTime * 1000)ms")
    print("  Total iterations: \(Self.stressTestIterations)")

    #expect(
      averageTime < Self.maxRegistrationTime,
      "Average registration time \(averageTime * 1000)ms exceeds threshold \(Self.maxRegistrationTime * 1000)ms"
    )
  }

  @Test("Memory usage remains stable during hotkey operations")
  func testMemoryUsageStability() async throws {
    let initialMemory = getCurrentMemoryUsage()
    let hotkeyManager = MockHotkeyManager()

    // Perform many registration operations
    for i in 0..<50 {
      let combo = KeyCombo(
        shortcut: .init(.a, modifiers: [.command, .option]),
        description: "Memory Test \(i)"
      )

      try await hotkeyManager.register(combo) {}
      await hotkeyManager.unregister(combo)
    }

    // Force memory cleanup
    autoreleasepool {}

    let finalMemory = getCurrentMemoryUsage()
    let memoryIncrease = finalMemory - initialMemory

    print("Memory Usage:")
    print("  Initial: \(initialMemory)MB")
    print("  Final: \(finalMemory)MB")
    print("  Increase: \(memoryIncrease)MB")

    #expect(
      memoryIncrease < Self.memoryThresholdMB,
      "Memory usage increased by \(memoryIncrease)MB, expected < \(Self.memoryThresholdMB)MB")
  }

  // MARK: - Error Handling Performance

  @Test("Error handling performance for invalid hotkeys")
  func testErrorHandlingPerformance() async throws {
    let errorHandler = await HotkeyErrorHandler()
    let invalidCombos = [
      KeyCombo(shortcut: .init(.a, modifiers: []), description: "No modifiers"),  // Invalid
      KeyCombo(shortcut: .init(.space, modifiers: [.command]), description: "System conflict"),  // Conflicts with Spotlight
      KeyCombo(shortcut: .init(.tab, modifiers: [.command]), description: "App switcher conflict"),  // Conflicts with system
    ]

    var totalTime: TimeInterval = 0

    for combo in invalidCombos {
      let startTime = CFAbsoluteTimeGetCurrent()

      do {
        try await errorHandler.validateShortcut(combo)
        #expect(Bool(false), "Should have thrown validation error for \(combo.displayString)")
      } catch {
        await errorHandler.handleError(error, for: combo)
      }

      let elapsed = CFAbsoluteTimeGetCurrent() - startTime
      totalTime += elapsed

      #expect(
        elapsed < 0.01,  // 10ms for error handling
        "Error handling for \(combo.displayString) took \(elapsed * 1000)ms, expected < 10ms")

      await errorHandler.dismissError()
    }

    let averageTime = totalTime / Double(invalidCombos.count)
    print("Error handling average time: \(averageTime * 1000)ms")
  }

  @Test("Alternative suggestion generation performance")
  func testAlternativeSuggestionPerformance() async throws {
    let errorHandler = await HotkeyErrorHandler()
    let conflictedCombo = KeyCombo.defaultShowHide()

    let startTime = CFAbsoluteTimeGetCurrent()

    let alternatives = await errorHandler.suggestAlternatives(for: conflictedCombo)

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

    #expect(
      elapsed < 0.05,  // 50ms for suggestion generation
      "Alternative suggestion generation took \(elapsed * 1000)ms, expected < 50ms")

    #expect(!alternatives.isEmpty, "Should provide alternative suggestions")
    #expect(alternatives.count <= 3, "Should limit suggestions to 3")

    print("Generated \(alternatives.count) alternatives in \(elapsed * 1000)ms")
  }

  // MARK: - Integration Performance Tests

  @Test("End-to-end configuration loading and hotkey setup performance")
  func testEndToEndSetupPerformance() async throws {
    let startTime = CFAbsoluteTimeGetCurrent()

    // Simulate full configuration loading and hotkey setup
    let config = Configuration()
    let hotkeyManager = MockHotkeyManager()

    // Register all configured hotkeys
    if let showHide = config.showHideHotkey {
      try await hotkeyManager.register(showHide) {}
    }

    if let settings = config.settingsHotkey {
      try await hotkeyManager.register(settings) {}
    }

    if let refresh = config.refreshHotkey {
      try await hotkeyManager.register(refresh) {}
    }

    let elapsed = CFAbsoluteTimeGetCurrent() - startTime

    #expect(
      elapsed < 0.2,  // 200ms for full setup
      "End-to-end setup took \(elapsed * 1000)ms, expected < 200ms")

    print("Full configuration setup completed in \(elapsed * 1000)ms")
  }

  // MARK: - Benchmark Utilities

  /// Measures memory usage in MB
  private func getCurrentMemoryUsage() -> Double {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(
          mach_task_self_,
          task_flavor_t(MACH_TASK_BASIC_INFO),
          $0,
          &count)
      }
    }

    if kerr == KERN_SUCCESS {
      return Double(info.resident_size) / (1024.0 * 1024.0)  // Convert to MB
    } else {
      return 0.0
    }
  }
}

// MARK: - Mock Hotkey Manager for Testing

/// Mock implementation of HotkeyManager for performance testing
private actor MockHotkeyManager {
  private var registeredHotkeys: [KeyCombo: () -> Void] = [:]
  private let registrationDelay: TimeInterval = 0.01  // 10ms simulated delay

  func register(_ combo: KeyCombo, handler: @escaping () -> Void) async throws {
    // Simulate registration work
    try await Task.sleep(nanoseconds: UInt64(registrationDelay * 1_000_000_000))

    // Check for conflicts
    if registeredHotkeys[combo] != nil {
      throw NSError(
        domain: "MockHotkeyManager", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Hotkey already registered"])
    }

    // Simulate system conflict checking
    if combo.hasSystemConflict {
      throw NSError(
        domain: "MockHotkeyManager", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "System conflict"])
    }

    // Register the hotkey
    registeredHotkeys[combo] = handler
  }

  func unregister(_ combo: KeyCombo) async {
    // Simulate unregistration work
    try? await Task.sleep(nanoseconds: UInt64(registrationDelay * 1_000_000_000))
    registeredHotkeys.removeValue(forKey: combo)
  }

  func isRegistered(_ combo: KeyCombo) async -> Bool {
    return registeredHotkeys[combo] != nil
  }

  func unregisterAll() async {
    registeredHotkeys.removeAll()
  }
}
