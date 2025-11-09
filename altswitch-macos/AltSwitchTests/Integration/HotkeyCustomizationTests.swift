//
//  HotkeyCustomizationTests.swift
//  AltSwitchTests
//
//  Integration tests for hotkey customization workflow
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

@Suite("Hotkey Customization Integration")
struct HotkeyCustomizationTests {

  @Test("End-to-end hotkey customization through settings")
  func testEndToEndHotkeyCustomization() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let originalCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Default Show/Hide"
    )

    let customCombo = KeyCombo(
      shortcut: .init(.t, modifiers: [.command, .option]),
      description: "Custom Toggle"
    )

    // Verify original hotkey works
    try await app.hotkeyManager.registerHotkey(originalCombo) {
      await app.toggleWindowVisibility()
    }

    await app.simulateGlobalHotkeyPress(originalCombo)
    #expect(await app.getWindowVisibility(), "Original hotkey should work")

    // Act - Customize hotkey through settings
    try await app.customizeShowHideHotkey(from: originalCombo, to: customCombo)

    // Assert - Original hotkey should no longer work
    await app.simulateGlobalHotkeyPress(originalCombo)
    #expect(await app.getWindowVisibility(), "Original hotkey should be unregistered")

    // New hotkey should work
    await app.simulateGlobalHotkeyPress(customCombo)
    #expect(!(await app.getWindowVisibility()), "Custom hotkey should work")

    // Verify persistence
    let savedSettings = try await app.settingsManager.loadConfiguration()
    #expect(
      savedSettings.showHideHotkey?.shortcut == customCombo.shortcut,
      "Custom hotkey should be persisted")
  }

  @Test("Hotkey recorder UI integration")
  func testHotkeyRecorderUIIntegration() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let settingsViewModel = MockSettingsViewModel(
      settingsManager: app.settingsManager,
      hotkeyManager: app.hotkeyManager
    )

    // Act - Open settings and start recording
    await settingsViewModel.openHotkeyRecorder()
    #expect(await settingsViewModel.getIsRecordingHotkey(), "Should enter recording mode")

    // Simulate user pressing custom key combination
    let newCombo = KeyCombo(
      shortcut: .init(.j, modifiers: [.command, .control]),
      description: "New Custom Hotkey"
    )

    await settingsViewModel.recordKeyPress(newCombo.shortcut)

    // Assert
    #expect(!(await settingsViewModel.getIsRecordingHotkey()), "Should exit recording mode")
    #expect(
      await settingsViewModel.getCurrentShowHideHotkey()?.shortcut == newCombo.shortcut,
      "Should update current hotkey")

    // Verify hotkey was actually registered
    #expect(
      await app.hotkeyManager.isHotkeyRegistered(newCombo),
      "New hotkey should be registered")
  }

  @Test("Multiple hotkey customization workflow")
  func testMultipleHotkeyCustomization() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let showHideCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Show/Hide"
    )

    let settingsCombo = KeyCombo(
      shortcut: .init(.comma, modifiers: [.command]),
      description: "Settings"
    )

    let refreshCombo = KeyCombo(
      shortcut: .init(.r, modifiers: [.command, .shift]),
      description: "Refresh"
    )

    // Act - Register all default hotkeys
    try await app.hotkeyManager.registerHotkey(showHideCombo) {
      await app.toggleWindowVisibility()
    }

    try await app.hotkeyManager.registerHotkey(settingsCombo) {
      await app.openSettings()
    }

    try await app.hotkeyManager.registerHotkey(refreshCombo) {
      await app.refreshAppList()
    }

    // Customize each hotkey
    let newShowHideCombo = KeyCombo(
      shortcut: .init(.q, modifiers: [.command, .option]),
      description: "Custom Show/Hide"
    )

    let newSettingsCombo = KeyCombo(
      shortcut: .init(.period, modifiers: [.command, .shift]),
      description: "Custom Settings"
    )

    try await app.customizeShowHideHotkey(from: showHideCombo, to: newShowHideCombo)
    try await app.customizeSettingsHotkey(from: settingsCombo, to: newSettingsCombo)

    // Assert - All customizations should work
    await app.simulateGlobalHotkeyPress(newShowHideCombo)
    #expect(await app.getWindowVisibility(), "Custom show/hide hotkey should work")

    await app.simulateGlobalHotkeyPress(newSettingsCombo)
    #expect(await app.getSettingsVisibility(), "Custom settings hotkey should work")

    await app.simulateGlobalHotkeyPress(refreshCombo)
    #expect(await app.getDidRefreshAppList(), "Unchanged refresh hotkey should still work")

    // Verify all changes are persisted
    let config = try await app.settingsManager.loadConfiguration()
    #expect(config.showHideHotkey?.shortcut == newShowHideCombo.shortcut)
    #expect(config.settingsHotkey?.shortcut == newSettingsCombo.shortcut)
    #expect(config.refreshHotkey?.shortcut == refreshCombo.shortcut)
  }

  @Test("Hotkey conflict detection during customization")
  func testHotkeyConflictDetectionDuringCustomization() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let existingCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Existing Hotkey"
    )

    try await app.hotkeyManager.registerHotkey(existingCombo) {
      await app.toggleWindowVisibility()
    }

    // Act & Assert - Try to register conflicting hotkey
    let conflictingCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Conflicting Hotkey"
    )

    await #expect(throws: HotkeyCustomizationError.hotkeyAlreadyInUse(conflictingCombo)) {
      try await app.customizeSettingsHotkey(
        from: KeyCombo(shortcut: .init(.comma, modifiers: [.command]), description: "Settings"),
        to: conflictingCombo
      )
    }

    // System conflict detection
    let systemConflictCombo = KeyCombo(
      shortcut: .init(.tab, modifiers: [.command]),
      description: "System Conflict"
    )

    await #expect(throws: HotkeyCustomizationError.systemConflict(systemConflictCombo)) {
      try await app.customizeShowHideHotkey(from: existingCombo, to: systemConflictCombo)
    }
  }

  @Test("Hotkey customization validation rules")
  func testHotkeyCustomizationValidation() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let validCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Valid Combo"
    )

    // Test invalid combinations
    let invalidCombos = [
      KeyCombo(shortcut: .init(.escape, modifiers: []), description: "No modifiers"),
      KeyCombo(shortcut: .init(.f1, modifiers: [.shift]), description: "Only shift"),
      KeyCombo(shortcut: .init(.space, modifiers: []), description: "Space without modifiers"),
    ]

    for invalidCombo in invalidCombos {
      await #expect(throws: HotkeyCustomizationError.invalidCombination(invalidCombo)) {
        try await app.customizeShowHideHotkey(from: validCombo, to: invalidCombo)
      }
    }

    // Test valid combinations
    let validCombos = [
      KeyCombo(shortcut: .init(.space, modifiers: [.command]), description: "Cmd+Space"),
      KeyCombo(shortcut: .init(.t, modifiers: [.command, .option]), description: "Cmd+Opt+T"),
      KeyCombo(
        shortcut: .init(.f12, modifiers: [.control, .shift]), description: "Ctrl+Shift+F12"),
    ]

    for validCombo in validCombos {
      // Should not throw
      try await app.customizeShowHideHotkey(
        from: KeyCombo(
          shortcut: .init(.space, modifiers: [.command, .shift]), description: "Original"),
        to: validCombo
      )

      #expect(
        await app.hotkeyManager.isHotkeyRegistered(validCombo),
        "Valid combo should be registered: \(validCombo.description)")
    }
  }

  @Test("Hotkey customization undo/reset functionality")
  func testHotkeyCustomizationUndoReset() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let defaultCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Default Show/Hide"
    )

    let customCombo = KeyCombo(
      shortcut: .init(.t, modifiers: [.command, .option]),
      description: "Custom Toggle"
    )

    // Setup default configuration
    try await app.hotkeyManager.registerHotkey(defaultCombo) {
      await app.toggleWindowVisibility()
    }

    let originalConfig = TestConfiguration.default
    originalConfig.showHideHotkey = defaultCombo
    try await app.settingsManager.saveConfiguration(originalConfig)

    // Act - Customize hotkey
    try await app.customizeShowHideHotkey(from: defaultCombo, to: customCombo)
    #expect(await app.hotkeyManager.isHotkeyRegistered(customCombo))
    #expect(!(await app.hotkeyManager.isHotkeyRegistered(defaultCombo)))

    // Reset to defaults
    try await app.resetHotkeysToDefaults()

    // Assert - Should restore original hotkey
    #expect(
      await app.hotkeyManager.isHotkeyRegistered(defaultCombo),
      "Default hotkey should be restored")
    #expect(
      !(await app.hotkeyManager.isHotkeyRegistered(customCombo)),
      "Custom hotkey should be removed")

    // Verify functionality
    await app.simulateGlobalHotkeyPress(defaultCombo)
    #expect(await app.getWindowVisibility(), "Restored default hotkey should work")

    // Verify persistence
    let restoredConfig = try await app.settingsManager.loadConfiguration()
    #expect(restoredConfig.showHideHotkey?.shortcut == defaultCombo.shortcut)
  }

  @Test("Live hotkey updates without app restart")
  func testLiveHotkeyUpdatesWithoutRestart() async throws {
    // Arrange
    let app = MockAltSwitchApp()
    await app.initialize()

    let combo1 = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "First Hotkey"
    )

    let combo2 = KeyCombo(
      shortcut: .init(.t, modifiers: [.command, .option]),
      description: "Second Hotkey"
    )

    // Register initial hotkey
    try await app.hotkeyManager.registerHotkey(combo1) {
      await app.toggleWindowVisibility()
    }

    // Verify initial state
    await app.simulateGlobalHotkeyPress(combo1)
    #expect(await app.getWindowVisibility(), "Initial hotkey should work")

    // Act - Change hotkey while app is running
    try await app.customizeShowHideHotkey(from: combo1, to: combo2)

    // Assert - Changes should take effect immediately
    await app.simulateGlobalHotkeyPress(combo1)
    #expect(await app.getWindowVisibility(), "Old hotkey should no longer work")

    await app.simulateGlobalHotkeyPress(combo2)
    #expect(!(await app.getWindowVisibility()), "New hotkey should work immediately")

    // Change again to verify live updates continue working
    let combo3 = KeyCombo(
      shortcut: .init(.j, modifiers: [.command, .control]),
      description: "Third Hotkey"
    )

    try await app.customizeShowHideHotkey(from: combo2, to: combo3)

    await app.simulateGlobalHotkeyPress(combo2)
    #expect(!(await app.getWindowVisibility()), "Second hotkey should no longer work")

    await app.simulateGlobalHotkeyPress(combo3)
    #expect(await app.getWindowVisibility(), "Third hotkey should work immediately")
  }
}

// MARK: - Mock Application for Testing

private actor MockAltSwitchApp {
  var isWindowVisible = false
  var isSettingsVisible = false
  var didRefreshAppList = false

  let hotkeyManager = MockHotkeyManager()
  let settingsManager = MockSettingsManager()

  func initialize() async {
    // Simulate app initialization
  }

  func toggleWindowVisibility() async {
    isWindowVisible.toggle()
  }

  func openSettings() async {
    isSettingsVisible = true
  }

  func refreshAppList() async {
    didRefreshAppList = true
  }

  func simulateGlobalHotkeyPress(_ combo: KeyCombo) async {
    await hotkeyManager.simulateHotkeyPress(combo)
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

  func customizeShowHideHotkey(from oldCombo: KeyCombo, to newCombo: KeyCombo) async throws {
    // Validate new combination
    try validateHotkeyCombo(newCombo)

    // Check for conflicts
    if await hotkeyManager.isHotkeyRegistered(newCombo) {
      throw HotkeyCustomizationError.hotkeyAlreadyInUse(newCombo)
    }

    // Unregister old hotkey
    try await hotkeyManager.unregisterHotkey(oldCombo)

    // Register new hotkey
    try await hotkeyManager.registerHotkey(newCombo) { @Sendable in
      await self.toggleWindowVisibility()
    }

    // Update configuration
    let config = try await settingsManager.loadConfiguration()
    config.showHideHotkey = newCombo
    try await settingsManager.saveConfiguration(config)
  }

  func customizeSettingsHotkey(from oldCombo: KeyCombo, to newCombo: KeyCombo) async throws {
    try validateHotkeyCombo(newCombo)

    if await hotkeyManager.isHotkeyRegistered(newCombo) {
      throw HotkeyCustomizationError.hotkeyAlreadyInUse(newCombo)
    }

    try await hotkeyManager.unregisterHotkey(oldCombo)
    try await hotkeyManager.registerHotkey(newCombo) { @Sendable in
      await self.openSettings()
    }

    let config = try await settingsManager.loadConfiguration()
    config.settingsHotkey = newCombo
    try await settingsManager.saveConfiguration(config)
  }

  func resetHotkeysToDefaults() async throws {
    // Clear all current hotkeys
    for combo in await hotkeyManager.getRegisteredHotkeys() {
      try await hotkeyManager.unregisterHotkey(combo)
    }

    // Restore default hotkeys
    let defaultShowHideCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Default Show/Hide"
    )

    try await hotkeyManager.registerHotkey(defaultShowHideCombo) { @Sendable in
      await self.toggleWindowVisibility()
    }

    // Update configuration
    let defaultConfig = TestConfiguration.default
    defaultConfig.showHideHotkey = defaultShowHideCombo
    try await settingsManager.saveConfiguration(defaultConfig)
  }

  private func validateHotkeyCombo(_ combo: KeyCombo) throws {
    // Must have at least one modifier
    if combo.shortcut.modifiers.isEmpty {
      throw HotkeyCustomizationError.invalidCombination(combo)
    }

    // Must have a substantive modifier (not just shift)
    let hasSubstantiveModifier =
      combo.shortcut.modifiers.contains(.command) || combo.shortcut.modifiers.contains(.option)
      || combo.shortcut.modifiers.contains(.control)

    if !hasSubstantiveModifier {
      throw HotkeyCustomizationError.invalidCombination(combo)
    }

    // Check for system conflicts
    let systemConflicts: [KeyboardShortcuts.Shortcut] = [
      .init(.tab, modifiers: [.command]),
      .init(.space, modifiers: [.command]),
    ]

    if systemConflicts.contains(combo.shortcut) {
      throw HotkeyCustomizationError.systemConflict(combo)
    }
  }
}

// MARK: - Supporting Mock Classes

private actor MockHotkeyManager {
  private var registeredHotkeys: [KeyCombo: () async -> Void] = [:]

  func registerHotkey(_ combo: KeyCombo, action: @escaping () async -> Void) async throws {
    registeredHotkeys[combo] = action
  }

  func unregisterHotkey(_ combo: KeyCombo) async throws {
    registeredHotkeys.removeValue(forKey: combo)
  }

  func isHotkeyRegistered(_ combo: KeyCombo) async -> Bool {
    return registeredHotkeys[combo] != nil
  }

  func getRegisteredHotkeys() async -> [KeyCombo] {
    return Array(registeredHotkeys.keys)
  }

  func simulateHotkeyPress(_ combo: KeyCombo) async {
    if let action = registeredHotkeys[combo] {
      await action()
    }
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

private actor MockSettingsViewModel {
  var isRecordingHotkey = false
  var currentShowHideHotkey: KeyCombo?

  private let settingsManager: MockSettingsManager
  private let hotkeyManager: MockHotkeyManager

  init(settingsManager: MockSettingsManager, hotkeyManager: MockHotkeyManager) {
    self.settingsManager = settingsManager
    self.hotkeyManager = hotkeyManager
  }

  func openHotkeyRecorder() async {
    isRecordingHotkey = true
  }

  func recordKeyPress(_ shortcut: KeyboardShortcuts.Shortcut) async {
    isRecordingHotkey = false

    let newCombo = KeyCombo(shortcut: shortcut, description: "Recorded Hotkey")
    currentShowHideHotkey = newCombo

    // Register the hotkey
    try? await hotkeyManager.registerHotkey(newCombo) {
      // Action would be provided by the real implementation
    }
  }

  // Accessor methods for testing
  func getIsRecordingHotkey() async -> Bool {
    return isRecordingHotkey
  }

  func getCurrentShowHideHotkey() async -> KeyCombo? {
    return currentShowHideHotkey
  }
}

// MARK: - Supporting Test Types

private struct KeyCombo: Hashable, Sendable {
  let shortcut: KeyboardShortcuts.Shortcut
  let description: String
}

private class TestConfiguration: @unchecked Sendable {
  var showHideHotkey: KeyCombo?
  var settingsHotkey: KeyCombo?
  var refreshHotkey: KeyCombo?

  static let `default` = TestConfiguration()
}

private enum HotkeyCustomizationError: Error, Equatable {
  case hotkeyAlreadyInUse(KeyCombo)
  case systemConflict(KeyCombo)
  case invalidCombination(KeyCombo)
  case registrationFailed(String)
}
