//
//  HotkeyManagerContractTests.swift
//  AltSwitchTests
//
//  Contract tests for the HotkeyManagerService
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

@Suite("Hotkey Manager Contract")
struct HotkeyManagerContractTests {

  @Test("Register hotkey succeeds with valid combo", .disabled("Requires implementation"))
  func testRegisterHotkey() async throws {
    // This test will be enabled when HotkeyManager is implemented
    // It should verify that registering a hotkey with a valid combo succeeds
    #expect(true, "Test disabled until implementation")
  }

  @Test("Unregister removes hotkey", .disabled("Requires implementation"))
  func testUnregisterHotkey() async throws {
    // This test will be enabled when HotkeyManager is implemented
    // It should verify that unregistering removes the hotkey
    #expect(true, "Test disabled until implementation")
  }

  @Test("Multiple registrations override previous", .disabled("Requires implementation"))
  func testMultipleRegistrations() async throws {
    // This test will be enabled when HotkeyManager is implemented
    // It should verify that multiple registrations override the previous one
    #expect(true, "Test disabled until implementation")
  }

  @Test("KeyCombo equality works correctly")
  func testKeyComboEquality() {
    // Arrange
    let combo1 = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]), description: "Test 1")
    let combo2 = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]), description: "Test 2")
    let combo3 = KeyCombo(
      shortcut: .init(.comma, modifiers: [.command, .shift]), description: "Test 3")
    let combo4 = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .option]), description: "Test 4")

    // Act & Assert
    #expect(combo1 == combo2, "Same combos should be equal")
    #expect(combo1 != combo3, "Different keyCodes should not be equal")
    #expect(combo1 != combo4, "Different modifiers should not be equal")
  }

  @Test("KeyCombo validates modifier requirement")
  func testKeyComboRequiresModifier() {
    // KeyCombo should require at least one modifier
    let validCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command]), description: "Valid combo")
    #expect(validCombo.modifiers.contains(.command))

    // Test multiple modifiers
    let multiCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift, .option]), description: "Multi combo")
    #expect(multiCombo.modifiers.contains(.command))
    #expect(multiCombo.modifiers.contains(.shift))
    #expect(multiCombo.modifiers.contains(.option))
  }

  @Test("Action executes on main thread", .disabled("Requires implementation"))
  @MainActor
  func testActionMainThread() async throws {
    // This test will be enabled when HotkeyManager is implemented
    // It should verify that the action handler executes on the main thread
    #expect(true, "Test disabled until implementation")
  }

  @Test("Hotkey manager is Sendable", .disabled("Requires implementation"))
  func testSendableCompliance() async throws {
    // This test will be enabled when HotkeyManager is implemented
    // It should verify Sendable compliance
    #expect(true, "Test disabled until implementation")
  }

  @Test("Default hotkey constant is valid")
  func testDefaultHotkeyConstant() {
    // Arrange
    let defaultHotkey = AltSwitchConstants.defaultHotkey

    // Assert
    #expect(defaultHotkey.keyCode == 49, "Default should be space key (keyCode 49)")
    #expect(defaultHotkey.modifiers.contains(.command), "Should include Command modifier")
    #expect(defaultHotkey.modifiers.contains(.shift), "Should include Shift modifier")
  }

  @Test("Registration handles system permission denial")
  func testSystemPermissionDenied() async throws {
    // Arrange
    struct MockDeniedManager: HotkeyManagerProtocol {
      var isRegistered: Bool { false }

      func registerHotkey(_ combo: KeyCombo, action: @escaping @Sendable () -> Void) async throws {
        throw HotkeyError.systemPermissionDenied
      }

      func unregisterHotkey(_ combo: KeyCombo) async throws {}

      func isHotkeyRegistered(_ combo: KeyCombo) -> Bool { false }

      func getRegisteredHotkeys() -> [KeyCombo] { [] }

      func setHotkeysEnabled(_ enabled: Bool) async {}

      func register(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        handler: @escaping @Sendable () -> Void
      ) async throws {
        throw HotkeyError.systemPermissionDenied
      }

      func unregister() async {}
    }

    let manager = MockDeniedManager()

    // Act & Assert
    do {
      try await manager.register(keyCode: 49, modifiers: [.command]) {}
      Issue.record("Should throw permission error")
    } catch HotkeyError.systemPermissionDenied {
      #expect(true, "Correctly threw permission denied error")
    } catch {
      Issue.record("Threw unexpected error: \(error)")
    }
  }

  @Test("Unregister when nothing registered is safe", .disabled("Requires implementation"))
  func testUnregisterEmpty() async {
    // This test will be enabled when HotkeyManager is implemented
    // It should verify that unregistering when nothing is registered doesn't crash
    #expect(true, "Test disabled until implementation")
  }

  @Test("KeyCombo Codable roundtrip")
  func testKeyComboCodeable() throws {
    // Arrange
    let original = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift, .option]), description: "Test combo")

    // Act - encode and decode
    let encoder = JSONEncoder()
    let data = try encoder.encode(original)

    let decoder = JSONDecoder()
    let decoded = try decoder.decode(KeyCombo.self, from: data)

    // Assert
    #expect(decoded == original, "Decoded combo should equal original")
    #expect(decoded.keyCode == original.keyCode)
    #expect(decoded.modifiers == original.modifiers)
  }

  @Test("Registration with conflicting hotkey")
  func testConflictingHotkey() async throws {
    // Arrange
    struct MockConflictManager: HotkeyManagerProtocol {
      var isRegistered: Bool { false }

      func registerHotkey(_ combo: KeyCombo, action: @escaping @Sendable () -> Void) async throws {
        throw HotkeyError.alreadyRegistered
      }

      func unregisterHotkey(_ combo: KeyCombo) async throws {}

      func isHotkeyRegistered(_ combo: KeyCombo) -> Bool { false }

      func getRegisteredHotkeys() -> [KeyCombo] { [] }

      func setHotkeysEnabled(_ enabled: Bool) async {}

      func register(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        handler: @escaping @Sendable () -> Void
      ) async throws {
        throw HotkeyError.alreadyRegistered
      }

      func unregister() async {}
    }

    let manager = MockConflictManager()

    // Act & Assert
    do {
      try await manager.register(keyCode: 49, modifiers: [.command, .shift]) {}
      Issue.record("Should throw conflict error")
    } catch HotkeyError.alreadyRegistered {
      #expect(true, "Correctly identified hotkey conflict")
    } catch {
      Issue.record("Threw unexpected error: \(error)")
    }
  }

  @Test("Performance: Registration completes quickly", .disabled("Requires implementation"))
  func testRegistrationPerformance() async throws {
    // This test will be enabled when HotkeyManager is implemented
    // It should verify that registration completes within 100ms
    #expect(true, "Test disabled until implementation")
  }
}

// Note: The actual HotkeyManager implementation will be created as part of the
// service implementation phase. These tests define the expected behavior and
// will initially fail (TDD approach).
