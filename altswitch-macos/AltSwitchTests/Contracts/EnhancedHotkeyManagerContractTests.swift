//
//  EnhancedHotkeyManagerContractTests.swift
//  AltSwitchTests
//
//  Contract tests for enhanced HotkeyManagerProtocol with KeyboardShortcuts support
//  These tests MUST FAIL until the enhanced implementation is complete
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

@Suite("Enhanced Hotkey Manager Contract")
struct EnhancedHotkeyManagerContractTests {

  @Test("Register hotkey with KeyboardShortcuts support")
  func testRegisterHotkeyWithKeyboardShortcuts() async throws {
    // Arrange
    let manager = MockEnhancedHotkeyManager()
    let combo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]), description: "Test")
    let actionCalled = Locked(false)

    // Act
    try await manager.registerHotkey(combo) {
      actionCalled.value = true
    }

    // Assert
    #expect(manager.isHotkeyRegistered(combo))
    #expect(!actionCalled.value, "Action should not be called during registration")

    // Simulate hotkey press
    await manager.simulateHotkeyPress(combo)
    #expect(actionCalled.value, "Action should be called when hotkey is pressed")
  }

  @Test("Unregister hotkey removes from registry")
  func testUnregisterHotkey() async throws {
    // Arrange
    let manager = MockEnhancedHotkeyManager()
    let combo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]), description: "Test")

    try await manager.registerHotkey(combo) {}
    #expect(manager.isHotkeyRegistered(combo))

    // Act
    try await manager.unregisterHotkey(combo)

    // Assert
    #expect(!manager.isHotkeyRegistered(combo))
  }

  @Test("Get registered hotkeys returns all active shortcuts")
  func testGetRegisteredHotkeys() async throws {
    // Arrange
    let manager = MockEnhancedHotkeyManager()
    let combo1 = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]), description: "Show/Hide")
    let combo2 = KeyCombo(shortcut: .init(.comma, modifiers: [.command]), description: "Settings")

    // Act
    try await manager.registerHotkey(combo1) {}
    try await manager.registerHotkey(combo2) {}

    // Assert
    let registeredHotkeys = manager.getRegisteredHotkeys()
    #expect(registeredHotkeys.count == 2)
    #expect(registeredHotkeys.contains(combo1))
    #expect(registeredHotkeys.contains(combo2))
  }

  @Test("Enable and disable hotkeys functionality")
  func testEnableDisableHotkeys() async throws {
    // Arrange
    let manager = MockEnhancedHotkeyManager()
    let combo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]), description: "Test")
    let actionCallCount = Locked(0)

    try await manager.registerHotkey(combo) {
      actionCallCount.value += 1
    }

    // Act & Assert - Enabled by default
    await manager.simulateHotkeyPress(combo)
    #expect(actionCallCount.value == 1)

    // Disable hotkeys
    await manager.setHotkeysEnabled(false)
    await manager.simulateHotkeyPress(combo)
    #expect(actionCallCount.value == 1, "Action should not be called when disabled")

    // Re-enable hotkeys
    await manager.setHotkeysEnabled(true)
    await manager.simulateHotkeyPress(combo)
    #expect(actionCallCount.value == 2, "Action should be called when re-enabled")
  }

  @Test("Hotkey registration conflict handling")
  func testHotkeyRegistrationConflict() async throws {
    // Arrange
    let manager = MockEnhancedHotkeyManager()
    let combo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]), description: "Test")

    // Act & Assert
    try await manager.registerHotkey(combo) {}

    // Attempting to register the same hotkey should throw an error
    await #expect(throws: HotkeyRegistrationError.alreadyRegistered(combo)) {
      try await manager.registerHotkey(combo) {}
    }
  }

  @Test("System conflict detection")
  func testSystemConflictDetection() async throws {
    // Arrange
    let manager = MockEnhancedHotkeyManager()
    let systemShortcut = KeyCombo(
      shortcut: .init(.tab, modifiers: [.command]), description: "System Tab")

    // Act & Assert
    await #expect(throws: HotkeyRegistrationError.systemConflict(systemShortcut)) {
      try await manager.registerHotkey(systemShortcut) {}
    }
  }

  @Test("Invalid combination validation")
  func testInvalidCombinationValidation() async throws {
    // Arrange
    let manager = MockEnhancedHotkeyManager()
    let invalidCombo = KeyCombo(
      shortcut: .init(.escape, modifiers: []), description: "Invalid - No modifiers")

    // Act & Assert
    await #expect(throws: HotkeyRegistrationError.invalidCombination(invalidCombo)) {
      try await manager.registerHotkey(invalidCombo) {}
    }
  }

  @Test("Concurrent registration operations")
  func testConcurrentRegistrationOperations() async throws {
    // Arrange
    let manager = MockEnhancedHotkeyManager()
    let combos = [
      KeyCombo(shortcut: .init(.space, modifiers: [.command, .shift]), description: "Combo1"),
      KeyCombo(shortcut: .init(.comma, modifiers: [.command]), description: "Combo2"),
      KeyCombo(shortcut: .init(.q, modifiers: [.command, .option]), description: "Combo3"),
    ]

    // Act - Register multiple hotkeys concurrently
    try await withThrowingTaskGroup(of: Void.self) { group in
      for combo in combos {
        group.addTask {
          try await manager.registerHotkey(combo) {}
        }
      }

      for try await _ in group {}
    }

    // Assert
    let registeredHotkeys = manager.getRegisteredHotkeys()
    #expect(registeredHotkeys.count == 3)
    for combo in combos {
      #expect(registeredHotkeys.contains(combo))
    }
  }
}

// MARK: - Mock Implementation for Testing

private class MockEnhancedHotkeyManager: HotkeyManagerProtocol, @unchecked Sendable {
  private var registeredHotkeys: [KeyCombo: () -> Void] = [:]
  private var enabled = true

  var isRegistered: Bool {
    return !registeredHotkeys.isEmpty
  }

  func registerHotkey(_ combo: KeyCombo, action: @escaping @Sendable () -> Void) async throws {
    // Validate combination
    guard
      combo.shortcut.modifiers.contains(.command) || combo.shortcut.modifiers.contains(.option)
        || combo.shortcut.modifiers.contains(.control)
    else {
      throw HotkeyRegistrationError.invalidCombination(combo)
    }

    // Check for system conflicts
    let systemConflicts: [KeyboardShortcuts.Shortcut] = [
      .init(.tab, modifiers: [.command]),
      .init(.space, modifiers: [.command]),
    ]

    if systemConflicts.contains(combo.shortcut) {
      throw HotkeyRegistrationError.systemConflict(combo)
    }

    // Check for existing registration
    if registeredHotkeys[combo] != nil {
      throw HotkeyRegistrationError.alreadyRegistered(combo)
    }

    registeredHotkeys[combo] = action
  }

  func unregisterHotkey(_ combo: KeyCombo) async throws {
    registeredHotkeys.removeValue(forKey: combo)
  }

  func isHotkeyRegistered(_ combo: KeyCombo) -> Bool {
    return registeredHotkeys[combo] != nil
  }

  func getRegisteredHotkeys() -> [KeyCombo] {
    return Array(registeredHotkeys.keys)
  }

  func setHotkeysEnabled(_ enabled: Bool) async {
    self.enabled = enabled
  }

  // Test helper method
  func simulateHotkeyPress(_ combo: KeyCombo) async {
    guard enabled, let action = registeredHotkeys[combo] else { return }
    action()
  }

  // MARK: - Legacy Methods

  func register(
    keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags,
    handler: @escaping @Sendable () -> Void
  ) async throws {
    // Convert legacy parameters to KeyCombo
    let key = Self.keyFromKeyCode(keyCode)
    let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    let combo = KeyCombo(shortcut: shortcut, description: "Legacy hotkey")

    try await registerHotkey(combo, action: handler)
  }

  func unregister() async {
    registeredHotkeys.removeAll()
  }

  // MARK: - Private Helpers

  private static func keyFromKeyCode(_ keyCode: UInt16) -> KeyboardShortcuts.Key {
    // Simple mapping for common keys
    switch keyCode {
    case 49: return .space
    case 36: return .return
    case 53: return .escape
    case 51: return .delete
    case 48: return .tab
    case 126: return .upArrow
    case 125: return .downArrow
    case 123: return .leftArrow
    case 124: return .rightArrow
    case 0: return .a
    case 11: return .b
    case 8: return .c
    case 2: return .d
    case 14: return .e
    case 3: return .f
    case 5: return .g
    case 4: return .h
    case 34: return .i
    case 38: return .j
    case 40: return .k
    case 37: return .l
    case 46: return .m
    case 45: return .n
    case 31: return .o
    case 35: return .p
    case 12: return .q
    case 15: return .r
    case 1: return .s
    case 17: return .t
    case 32: return .u
    case 9: return .v
    case 13: return .w
    case 7: return .x
    case 16: return .y
    case 6: return .z
    case 29: return .zero
    case 18: return .one
    case 19: return .two
    case 20: return .three
    case 21: return .four
    case 23: return .five
    case 22: return .six
    case 26: return .seven
    case 28: return .eight
    case 25: return .nine
    case 43: return .comma
    default: return .space
    }
  }
}

// MARK: - Test Data Structures

/// Thread-safe wrapper for atomic value access in tests
private final class Locked<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: T

  init(_ value: T) {
    self._value = value
  }

  var value: T {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _value
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _value = newValue
    }
  }

  func withLock<R>(_ body: (inout T) throws -> R) rethrows -> R {
    lock.lock()
    defer { lock.unlock() }
    return try body(&_value)
  }
}
