// swiftlint:disable all
#if false
//
//  GlobalHotkeyIntegrationTests.swift
//  AltSwitchTests
//
//  Integration tests for global hotkey activation workflow
//  These tests MUST FAIL until the enhanced implementation is complete
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

@Suite("Global Hotkey Integration")
struct GlobalHotkeyIntegrationTests {

  @Test("End-to-end hotkey registration and activation")
  func testEndToEndHotkeyWorkflow() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    // Act - Register global hotkey
    let showHideCombo = TestKeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Show/Hide AltSwitch"
    )

    try await app.hotkeyManager.registerHotkey(showHideCombo) {
      await app.toggleWindowVisibility()
    }

    // Assert - Initial state
    #expect(await !app.getWindowVisibility(), "Window should be hidden initially")

    // Act - Simulate hotkey press
    await app.simulateGlobalHotkeyPress(showHideCombo)

    // Assert - Window should appear
    #expect(await app.getWindowVisibility(), "Window should be visible after first hotkey press")
    #expect(await app.getWindowAppearanceTime() < 0.1, "Window should appear within 100ms")

    // Act - Press hotkey again
    await app.simulateGlobalHotkeyPress(showHideCombo)

    // Assert - Window should hide
    #expect(await !app.getWindowVisibility(), "Window should be hidden after second hotkey press")
  }

  @Test("Hotkey activation from different application contexts")
  func testHotkeyActivationFromDifferentContexts() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let showHideCombo = TestKeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Show/Hide AltSwitch"
    )

    try await app.hotkeyManager.registerHotkey(showHideCombo) {
      await app.toggleWindowVisibility()
    }

    // Test contexts
    let testContexts = ["com.apple.finder", "com.apple.Safari", "com.microsoft.VSCode"]

    for context in testContexts {
      // Act - Simulate hotkey press from different app context
      await app.setActiveApplicationContext(context)
      await app.simulateGlobalHotkeyPress(showHideCombo)

      // Assert
      #expect(await app.getWindowVisibility(), "Hotkey should work from \(context)")
      #expect(await app.getCurrentContext() == context, "Context should be preserved")

      // Hide window for next test
      await app.simulateGlobalHotkeyPress(showHideCombo)
    }
  }

  @Test("Multiple hotkey registration and activation")
  func testMultipleHotkeyRegistration() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let showHideCombo = TestKeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Show/Hide AltSwitch"
    )

    let settingsCombo = TestKeyCombo(
      shortcut: .init(.comma, modifiers: [.command]),
      description: "Open Settings"
    )

    let refreshCombo = TestKeyCombo(
      shortcut: .init(.r, modifiers: [.command, .shift]),
      description: "Refresh App List"
    )

    // Act - Register multiple hotkeys
    try await app.hotkeyManager.registerHotkey(showHideCombo) {
      await app.toggleWindowVisibility()
    }

    try await app.hotkeyManager.registerHotkey(settingsCombo) {
      await app.openSettings()
    }

    try await app.hotkeyManager.registerHotkey(refreshCombo) {
      await app.refreshAppList()
    }

    // Assert - All hotkeys should be registered
    #expect(await app.hotkeyManager.isHotkeyRegistered(showHideCombo))
    #expect(await app.hotkeyManager.isHotkeyRegistered(settingsCombo))
    #expect(await app.hotkeyManager.isHotkeyRegistered(refreshCombo))

    // Test each hotkey activation
    await app.simulateGlobalHotkeyPress(showHideCombo)
    #expect(await app.getWindowVisibility(), "Show/hide hotkey should work")

    await app.simulateGlobalHotkeyPress(settingsCombo)
    #expect(await app.getSettingsVisibility(), "Settings hotkey should work")

    await app.simulateGlobalHotkeyPress(refreshCombo)
    #expect(await app.getDidRefreshAppList(), "Refresh hotkey should work")
  }

  @Test("Hotkey persistence across app restarts")
  func testHotkeyPersistenceAcrossRestarts() async throws {
    // Arrange - First app instance
    let app1 = MockAltSwitchApp()
    await app1.initialize()

    let customCombo = TestKeyCombo(
      shortcut: .init(.t, modifiers: [.command, .option]),
      description: "Custom Toggle"
    )

    // Act - Register custom hotkey and save settings
    try await app1.hotkeyManager.registerHotkey(customCombo) {
      await app1.toggleWindowVisibility()
    }

    let settings = TestConfiguration.default
    settings.showHideHotkey = customCombo
    try await app1.settingsManager.saveConfiguration(settings)

    // Simulate app restart
    await app1.shutdown()

    // Arrange - Second app instance (simulating restart)
    let app2 = MockAltSwitchApp()
    await app2.initialize()

    // Assert - Custom hotkey should be restored
    #expect(
      await app2.hotkeyManager.isHotkeyRegistered(customCombo),
      "Custom hotkey should be restored after restart")

    // Test activation
    await app2.simulateGlobalHotkeyPress(customCombo)
    #expect(await app2.getWindowVisibility(), "Restored hotkey should work")
  }

  @Test("Hotkey conflict resolution workflow")
  func testHotkeyConflictResolution() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    // Simulate system hotkey conflict
    let conflictingCombo = TestKeyCombo(
      shortcut: .init(.tab, modifiers: [.command]),
      description: "Conflicting System Shortcut"
    )

    // Act & Assert - Should detect and handle conflict
    await #expect(throws: HotkeyRegistrationError.systemConflict(conflictingCombo)) {
      try await app.hotkeyManager.registerHotkey(conflictingCombo) {
        await app.toggleWindowVisibility()
      }
    }

    // Verify fallback hotkey is suggested/used
    let fallbackCombo = await app.suggestAlternativeHotkey(for: conflictingCombo)
    #expect(fallbackCombo != conflictingCombo, "Should suggest alternative hotkey")

    // Should be able to register the alternative
    try await app.hotkeyManager.registerHotkey(fallbackCombo) {
      await app.toggleWindowVisibility()
    }

    #expect(await app.hotkeyManager.isHotkeyRegistered(fallbackCombo))
  }

  @Test("Performance requirements for hotkey response")
  func testHotkeyResponsePerformance() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let combo = TestKeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Performance Test"
    )

    try await app.hotkeyManager.registerHotkey(combo) {
      await app.toggleWindowVisibility()
    }

    // Act & Assert - Test response time
    for i in 1...10 {
      let startTime = Date()
      await app.simulateGlobalHotkeyPress(combo)
      let responseTime = Date().timeIntervalSince(startTime)

      #expect(
        responseTime < 0.1,
        "Hotkey response #\(i) should be under 100ms, was \(responseTime * 1000)ms")

      // Reset for next test
      if await app.getWindowVisibility() {
        await app.simulateGlobalHotkeyPress(combo)
      }
    }
  }

  @Test("Accessibility integration with hotkeys")
  func testAccessibilityIntegrationWithHotkeys() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    // Simulate accessibility permissions denied
    await app.setAccessibilityPermissions(granted: false)

    let combo = TestKeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Accessibility Test"
    )

    // Act - Register hotkey (should work)
    try await app.hotkeyManager.registerHotkey(combo) {
      await app.toggleWindowVisibility()
    }

    // Press hotkey - should show permission prompt
    await app.simulateGlobalHotkeyPress(combo)

    // Assert
    #expect(
      await app.getDidShowAccessibilityPrompt(), "Should show accessibility permission prompt")
    #expect(await !app.getWindowVisibility(), "Window should not appear without permissions")

    // Grant permissions and try again
    await app.setAccessibilityPermissions(granted: true)
    await app.simulateGlobalHotkeyPress(combo)

    #expect(await app.getWindowVisibility(), "Window should appear after permissions granted")
  }
}

// MARK: - Mock Application for Testing

private actor MockAltSwitchApp {
  var isWindowVisible = false
  var isSettingsVisible = false
  var didRefreshAppList = false
  var windowAppearanceTime: TimeInterval = 0
  var currentContext = ""
  var didShowAccessibilityPrompt = false
  var accessibilityPermissionsGranted = false

  let hotkeyManager = MockHotkeyManager()
  let settingsManager = MockSettingsManager()

  func initialize() async {
    // Simulate app initialization
    accessibilityPermissionsGranted = true
  }

  func shutdown() async {
    // Simulate app shutdown
    await hotkeyManager.unregisterAllHotkeys()
  }

  func toggleWindowVisibility() async {
    guard accessibilityPermissionsGranted else {
      didShowAccessibilityPrompt = true
      return
    }

    let startTime = Date()
    isWindowVisible.toggle()
    windowAppearanceTime = Date().timeIntervalSince(startTime)
  }

  func openSettings() async {
    isSettingsVisible = true
  }

  func refreshAppList() async {
    didRefreshAppList = true
  }

  func setActiveApplicationContext(_ bundleId: String) async {
    currentContext = bundleId
  }

  func simulateGlobalHotkeyPress(_ combo: TestKeyCombo) async {
    await hotkeyManager.simulateHotkeyPress(combo)
  }

  func suggestAlternativeHotkey(for combo: TestKeyCombo) async -> TestKeyCombo {
    // Simple fallback logic
    return TestKeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Alternative Hotkey"
    )
  }

  func setAccessibilityPermissions(granted: Bool) async {
    accessibilityPermissionsGranted = granted
    didShowAccessibilityPrompt = false
  }

  // Methods to safely access actor state from tests
  func getWindowVisibility() async -> Bool {
    return isWindowVisible
  }

  func getSettingsVisibility() async -> Bool {
    return isSettingsVisible
  }

  func getDidRefreshAppList() async -> Bool {
    return didRefreshAppList
  }

  func getWindowAppearanceTime() async -> TimeInterval {
    return windowAppearanceTime
  }

  func getCurrentContext() async -> String {
    return currentContext
  }

  func getDidShowAccessibilityPrompt() async -> Bool {
    return didShowAccessibilityPrompt
  }
}

// MARK: - Supporting Mock Classes

private actor MockHotkeyManager {
  private var registeredHotkeys: [TestKeyCombo: () async -> Void] = [:]

  func registerHotkey(_ combo: TestKeyCombo, action: @escaping () async -> Void) async throws {
    // Check for system conflicts
    if combo.shortcut == .init(.tab, modifiers: [.command]) {
      throw HotkeyRegistrationError.systemConflict(combo)
    }

    registeredHotkeys[combo] = action
  }

  func isHotkeyRegistered(_ combo: TestKeyCombo) async -> Bool {
    return registeredHotkeys[combo] != nil
  }

  func simulateHotkeyPress(_ combo: TestKeyCombo) async {
    if let action = registeredHotkeys[combo] {
      await action()
    }
  }

  func unregisterAllHotkeys() async {
    registeredHotkeys.removeAll()
  }
}

private actor MockSettingsManager {
  private var configuration = TestConfiguration.default

  func saveConfiguration(_ config: TestConfiguration) async throws {
    configuration = config
  }

  func loadConfiguration() async throws -> TestConfiguration {
    return configuration
  }
}

// MARK: - Supporting Test Types

private struct TestKeyCombo: Equatable, Hashable {
  let shortcut: KeyboardShortcuts.Shortcut
  let description: String
}

private class TestConfiguration: @unchecked Sendable {
  var showHideHotkey: TestKeyCombo?

  static let `default` = TestConfiguration()
}

private enum HotkeyRegistrationError: Error, Equatable {
  case systemConflict(TestKeyCombo)
}
#endif
// swiftlint:enable all
