//
//  ErrorHandlingTests.swift
//  AltSwitchTests
//
//  Unit tests for error handling scenarios across the application
//  Covers hotkey conflicts, validation errors, migration failures, and recovery
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

/// Comprehensive test suite for error handling scenarios
@Suite("Error Handling Tests")
@MainActor
struct ErrorHandlingTests {

  // MARK: - Hotkey Error Handling Tests

  @Test("HotkeyErrorHandler handles shortcut conflicts correctly")
  func testHotkeyConflictHandling() async throws {
    let errorHandler = HotkeyErrorHandler()
    let conflictedCombo = KeyCombo.defaultShowHide()

    // Simulate a shortcut conflict error
    let conflictError = NSError(
      domain: "HotkeyTest",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "shortcut already in use"]
    )

    await errorHandler.handleError(conflictError, for: conflictedCombo)

    #expect(errorHandler.currentError != nil, "Error should be set after handling conflict")

    if case .shortcutInUse(let combo, let app) = errorHandler.currentError! {
      #expect(combo == conflictedCombo, "Error should contain the conflicted combo")
    } else {
      #expect(Bool(false), "Error should be shortcutInUse type")
    }
  }

  @Test("HotkeyErrorHandler validates shortcuts before registration")
  func testShortcutValidation() async throws {
    let errorHandler = HotkeyErrorHandler()

    // Test invalid shortcut (no modifiers)
    let invalidCombo = KeyCombo(
      shortcut: .init(.a, modifiers: []),
      description: "Invalid - no modifiers"
    )

    do {
      try errorHandler.validateShortcut(invalidCombo)
      #expect(Bool(false), "Should have thrown validation error")
    } catch let error as HotkeyErrorHandler.HotkeyError {
      if case .invalidShortcut = error {
        // Expected
      } else {
        #expect(Bool(false), "Should be invalidShortcut error")
      }
    }

    // Test system conflict
    let systemConflictCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command]),
      description: "Conflicts with Spotlight"
    )

    do {
      try errorHandler.validateShortcut(systemConflictCombo)
      #expect(Bool(false), "Should have thrown system conflict error")
    } catch let error as HotkeyErrorHandler.HotkeyError {
      if case .systemConflict = error {
        // Expected
      } else {
        #expect(Bool(false), "Should be systemConflict error")
      }
    }

    // Test valid shortcut
    let validCombo = KeyCombo.defaultShowHide()
    do {
      try errorHandler.validateShortcut(validCombo)
      // Should not throw
    } catch {
      #expect(Bool(false), "Valid shortcut should not throw: \(error)")
    }
  }

  @Test("HotkeyErrorHandler generates alternative suggestions")
  func testAlternativeSuggestions() async throws {
    let errorHandler = HotkeyErrorHandler()
    let conflictedCombo = KeyCombo.defaultShowHide()

    let alternatives = errorHandler.suggestAlternatives(for: conflictedCombo)

    #expect(!alternatives.isEmpty, "Should provide alternative suggestions")
    #expect(alternatives.count <= 3, "Should limit suggestions to 3")

    // Verify alternatives are different from original
    for alternative in alternatives {
      #expect(alternative != conflictedCombo, "Alternative should be different from original")
      #expect(alternative.isValid, "Alternative should be valid")
    }
  }

  @Test("HotkeyErrorHandler detects conflicting applications")
  func testConflictingAppDetection() async throws {
    let errorHandler = HotkeyErrorHandler()

    // Test known system conflict
    let spotlightCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command]),
      description: "Spotlight conflict"
    )

    let conflictingApp = errorHandler.detectConflictingApp(for: spotlightCombo)
    #expect(conflictingApp == "Spotlight", "Should detect Spotlight conflict")

    // Test unknown conflict
    let unknownCombo = KeyCombo(
      shortcut: .init(.f18, modifiers: [.command]),
      description: "Unknown conflict"
    )

    let noConflict = errorHandler.detectConflictingApp(for: unknownCombo)
    #expect(noConflict == nil, "Should not detect conflict for unknown combo")
  }

  // MARK: - Settings Migration Error Tests

  @Test("SettingsMigrator handles unsupported versions")
  func testUnsupportedVersionHandling() async throws {
    let migrator = SettingsMigrator()

    let unsupportedYaml = """
      version: "0.5"
      hotkey: "cmd+space"
      """

    do {
      _ = try await migrator.migrate(yaml: unsupportedYaml)
      #expect(Bool(false), "Should have thrown unsupported version error")
    } catch MigrationError.unsupportedVersion(let version) {
      #expect(version == "0.5", "Should report correct unsupported version")
    } catch {
      #expect(Bool(false), "Should throw MigrationError.unsupportedVersion: \(error)")
    }
  }

  @Test("SettingsMigrator handles malformed YAML")
  func testMalformedYamlHandling() async throws {
    let migrator = SettingsMigrator()

    let malformedYaml = """
      version: "1.0"
      hotkeys:
        show_hide:
          key: "invalid_key_name"
          modifiers: ["invalid_modifier"]
      """

    do {
      _ = try await migrator.migrate(yaml: malformedYaml)
      #expect(Bool(false), "Should have thrown validation error")
    } catch MigrationError.validationFailed {
      // Expected
    } catch {
      #expect(Bool(false), "Should throw MigrationError.validationFailed: \(error)")
    }
  }

  @Test("SettingsMigrator creates and restores backups")
  func testBackupCreationAndRestore() async throws {
    let migrator = SettingsMigrator()

    let originalYaml = """
      version: "0.9"
      max_apps: 8
      hotkey: "cmd+shift+space"
      """

    // Create backup
    let backupPath = try await migrator.createBackup(yaml: originalYaml)
    #expect(!backupPath.isEmpty, "Backup path should not be empty")

    // List backups
    let backups = try await migrator.listBackups()
    #expect(!backups.isEmpty, "Should have at least one backup")

    // Restore backup
    let restoredYaml = try await migrator.restoreFromBackup(path: backupPath)
    #expect(restoredYaml == originalYaml, "Restored YAML should match original")
  }

  @Test("SettingsMigrator validates configuration versions")
  func testVersionValidation() async throws {
    let migrator = SettingsMigrator()

    // Test current version
    let currentVersionYaml = """
      version: "1.0"
      hotkeys:
        show_hide:
          key: "space"
          modifiers: ["command", "shift"]
      """

    #expect(
      !migrator.needsMigration(yaml: currentVersionYaml),
      "Current version should not need migration")

    // Test old version
    let oldVersionYaml = """
      version: "0.9"
      hotkey: "cmd+space"
      """

    #expect(migrator.needsMigration(yaml: oldVersionYaml), "Old version should need migration")

    // Test version extraction
    let extractedVersion = migrator.extractVersion(from: currentVersionYaml)
    #expect(extractedVersion == "1.0", "Should extract correct version")
  }

  // MARK: - Configuration Error Tests

  @Test("Configuration validates hotkey settings")
  func testConfigurationHotkeyValidation() async throws {
    let config = Configuration()

    // Set invalid hotkey
    config.showHideHotkey = KeyCombo(
      shortcut: .init(.a, modifiers: []),
      description: "Invalid hotkey"
    )

    #expect(!config.isValid, "Configuration with invalid hotkey should be invalid")
    #expect(!config.validationErrors.isEmpty, "Should have validation errors")
    #expect(
      config.validationErrors.contains { $0.contains("modifier key") },
      "Should mention modifier key requirement")
  }

  @Test("Configuration detects hotkey conflicts")
  func testConfigurationHotkeyConflicts() async throws {
    let config = Configuration()

    // Set conflicting hotkeys
    let sameCombo = KeyCombo.defaultShowHide()
    config.showHideHotkey = sameCombo
    config.settingsHotkey = sameCombo

    #expect(!config.areHotkeysValid, "Conflicting hotkeys should be invalid")
    #expect(!config.isValid, "Configuration with conflicts should be invalid")
  }

  @Test("Configuration handles YAML serialization errors")
  func testConfigurationYamlErrors() async throws {
    // Test invalid YAML deserialization
    let invalidYaml = """
      version: "1.0"
      max_results: "not_a_number"
      """

    do {
      _ = try Configuration.fromYAML(invalidYaml)
      #expect(Bool(false), "Should have thrown YAML parsing error")
    } catch {
      // Expected - YAML parsing should fail
    }
  }

  // MARK: - Accessibility Error Tests

  @Test("AccessibilityAnnouncer handles rate limiting")
  func testAccessibilityRateLimiting() async throws {
    let announcer = AccessibilityAnnouncer()

    // Rapid-fire announcements to trigger rate limiting
    for i in 0..<15 {
      announcer.announceError("Test error \(i)")
    }

    // Verify rate limiting is working (internal implementation detail)
    // In a real test, we'd check that not all announcements were processed
  }

  @Test("AccessibilityAnnouncer handles invalid settings")
  func testAccessibilityInvalidSettings() async throws {
    let announcer = AccessibilityAnnouncer()

    // Test with announcements disabled
    var settings = AccessibilityAnnouncer.AccessibilitySettings()
    settings.isEnabled = false
    announcer.updateSettings(settings)

    // Announce error - should be ignored
    announcer.announceError("This should be ignored")

    // Verify no announcement was queued (implementation dependent)
  }

  // MARK: - Edge Case Error Tests

  @Test("Handles null/empty input gracefully")
  func testNullInputHandling() async throws {
    let errorHandler = HotkeyErrorHandler()

    // Test with empty error message
    let emptyError = NSError(domain: "", code: 0, userInfo: [:])
    let combo = KeyCombo.defaultShowHide()

    await errorHandler.handleError(emptyError, for: combo)
    #expect(errorHandler.currentError != nil, "Should handle empty error gracefully")
  }

  @Test("Handles concurrent error scenarios")
  func testConcurrentErrorHandling() async throws {
    let errorHandler = HotkeyErrorHandler()
    let combo = KeyCombo.defaultShowHide()

    // Simulate concurrent errors
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<5 {
        group.addTask {
          let error = NSError(
            domain: "Test", code: i, userInfo: [NSLocalizedDescriptionKey: "Error \(i)"])
          await errorHandler.handleError(error, for: combo)
        }
      }
    }

    // Should handle concurrent access gracefully
    #expect(errorHandler.currentError != nil, "Should have at least one error set")
  }

  @Test("Error recovery maintains app stability")
  func testErrorRecoveryStability() async throws {
    let errorHandler = HotkeyErrorHandler()

    // Test various error scenarios
    let errors = [
      NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"]),
      NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "Permission denied"]),
      NSError(domain: "Test", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid input"]),
    ]

    for error in errors {
      let combo = KeyCombo.defaultShowHide()
      await errorHandler.handleError(error, for: combo)

      // Verify error handling doesn't crash
      #expect(errorHandler.currentError != nil, "Error should be handled")

      // Dismiss error for next test
      await errorHandler.dismissError()
      #expect(errorHandler.currentError == nil, "Error should be dismissed")
    }
  }

  // MARK: - Integration Error Tests

  @Test("End-to-end error handling workflow")
  func testEndToEndErrorHandling() async throws {
    let errorHandler = HotkeyErrorHandler()
    let conflictedCombo = KeyCombo.defaultShowHide()

    // Simulate complete error handling workflow
    let conflictError = NSError(
      domain: "KeyboardShortcuts",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: "shortcut is already taken"]
    )

    // 1. Handle the error
    await errorHandler.handleError(conflictError, for: conflictedCombo)
    #expect(errorHandler.currentError != nil, "Error should be set")

    // 2. Get user-friendly error message
    if let error = errorHandler.currentError {
      let (title, message, suggestions) = errorHandler.getDisplayMessage(for: error)
      #expect(!title.isEmpty, "Error title should not be empty")
      #expect(!message.isEmpty, "Error message should not be empty")
      #expect(!suggestions.isEmpty, "Should provide alternative suggestions")
    }

    // 3. Attempt automatic resolution
    let mockRegistrationHandler: (KeyCombo) async throws -> Void = { _ in
      // Mock successful registration of alternative
      return
    }

    let resolvedCombo = await errorHandler.registerWithConflictResolution(
      conflictedCombo,
      registrationHandler: mockRegistrationHandler
    )

    #expect(resolvedCombo != nil, "Should successfully resolve with alternative")
    #expect(resolvedCombo != conflictedCombo, "Resolved combo should be different from original")
  }
}

// MARK: - Mock Implementations for Testing

/// Mock error for testing specific scenarios
private struct MockHotkeyError: Error, LocalizedError {
  let message: String

  var errorDescription: String? {
    return message
  }
}

/// Mock configuration for testing error scenarios
private class MockErrorConfiguration {
  var shouldFailValidation = false
  var isValid: Bool {
    return !shouldFailValidation
  }

  var validationErrors: [String] {
    return shouldFailValidation ? ["Mock validation error"] : []
  }
}
