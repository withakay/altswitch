//
//  KeyboardShortcutsHotkeyManager.swift
//  AltSwitch
//
//  Enhanced hotkey manager using KeyboardShortcuts framework
//  Supports multiple hotkey registration, conflict detection, and enable/disable functionality
//

import AppKit
import Foundation
import KeyboardShortcuts

// MARK: - Enhanced Protocol

/// Enhanced protocol for managing global hotkeys with KeyboardShortcuts support
protocol EnhancedHotkeyManagerProtocol: Sendable {
  /// Register a global hotkey with action
  func registerHotkey(_ combo: KeyCombo, action: @escaping @Sendable () -> Void) async throws

  /// Unregister a specific hotkey
  func unregisterHotkey(_ combo: KeyCombo) async throws

  /// Check if a hotkey is currently registered
  func isHotkeyRegistered(_ combo: KeyCombo) -> Bool

  /// Get all currently registered hotkeys
  func getRegisteredHotkeys() -> [KeyCombo]

  /// Enable or disable all hotkeys
  func setHotkeysEnabled(_ enabled: Bool) async
}

// MARK: - Error Types

/// Errors that can occur during hotkey registration
enum HotkeyRegistrationError: Error, Equatable {
  case alreadyRegistered(KeyCombo)
  case systemConflict(KeyCombo)
  case invalidCombination(KeyCombo)
  case registrationFailed(String)
}

// MARK: - Implementation

/// KeyboardShortcuts-based implementation of EnhancedHotkeyManagerProtocol and legacy HotkeyManagerProtocol
final class KeyboardShortcutsHotkeyManager: EnhancedHotkeyManagerProtocol, HotkeyManagerProtocol,
  Sendable
{
  // MARK: - Private Properties

  private let registeredHotkeys = SendableBox<[KeyCombo: HotkeyRegistration]>([:])
  private let isEnabled = SendableBox<Bool>(true)
  private let nextShortcutId = SendableBox<Int>(0)

  // MARK: - Supporting Types

  private struct HotkeyRegistration: Sendable {
    let name: KeyboardShortcuts.Name
    let action: @Sendable () -> Void
    let combo: KeyCombo
  }

  // MARK: - Initialization

  init() {
    // Initialize with clean state
  }

  deinit {
    // Clean up all registrations
    for registration in registeredHotkeys.value.values {
      KeyboardShortcuts.disable(registration.name)
    }
  }

  // MARK: - EnhancedHotkeyManagerProtocol Implementation

  func registerHotkey(_ combo: KeyCombo, action: @escaping @Sendable () -> Void) async throws {
    // Validate combination
    try validateHotkeyCombo(combo)

    // Check for existing registration
    if registeredHotkeys.value[combo] != nil {
      throw HotkeyRegistrationError.alreadyRegistered(combo)
    }

    // Create unique name for this hotkey
    let shortcutName = createUniqueShortcutName()

    // Create registration
    let registration = HotkeyRegistration(
      name: shortcutName,
      action: action,
      combo: combo
    )

    // Set the shortcut value on main thread
    await MainActor.run {
      KeyboardShortcuts.setShortcut(combo.shortcut, for: shortcutName)

      // Set up the handler
      KeyboardShortcuts.onKeyUp(for: shortcutName) { [weak self] in
        guard let self = self, self.isEnabled.value else { return }
        action()
      }
    }

    // Store registration
    registeredHotkeys.modify { $0[combo] = registration }
  }

  func unregisterHotkey(_ combo: KeyCombo) async throws {
    guard let registration = registeredHotkeys.value[combo] else {
      return  // Not registered, nothing to do
    }

    // Disable the keyboard shortcut on main thread
    await MainActor.run {
      KeyboardShortcuts.disable(registration.name)
    }

    // Remove from our registry
    _ = registeredHotkeys.modify { $0.removeValue(forKey: combo) }
  }

  func isHotkeyRegistered(_ combo: KeyCombo) -> Bool {
    return registeredHotkeys.value[combo] != nil
  }

  func getRegisteredHotkeys() -> [KeyCombo] {
    return Array(registeredHotkeys.value.keys)
  }

  func setHotkeysEnabled(_ enabled: Bool) async {
    isEnabled.modify { $0 = enabled }

    // KeyboardShortcuts doesn't have a global enable/disable,
    // so we handle this in our onKeyUp handlers
  }

  // MARK: - Legacy HotkeyManagerProtocol Implementation

  var isRegistered: Bool {
    return !registeredHotkeys.value.isEmpty
  }

  func register(
    keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags,
    handler: @escaping @Sendable () -> Void
  ) async throws {
    // Convert legacy keyCode to KeyboardShortcuts.Key
    guard let key = keyFromCode(keyCode) else {
      throw HotkeyRegistrationError.registrationFailed("Unknown key code: \(keyCode)")
    }

    let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    let combo = KeyCombo(shortcut: shortcut, description: "Legacy Hotkey")

    try await registerHotkey(combo, action: handler)
  }

  func unregister() async {
    for combo in getRegisteredHotkeys() {
      try? await unregisterHotkey(combo)
    }
  }

  // MARK: - Private Helper Methods

  private func validateHotkeyCombo(_ combo: KeyCombo) throws {
    // Check if valid (has meaningful modifiers)
    if !combo.isValid {
      throw HotkeyRegistrationError.invalidCombination(combo)
    }

    // Check for system conflicts
    if combo.hasSystemConflict {
      throw HotkeyRegistrationError.systemConflict(combo)
    }

    // Additional system conflicts not covered by KeyCombo
    let additionalSystemConflicts: [KeyboardShortcuts.Shortcut] = [
      .init(.tab, modifiers: [.command])  // System app switcher
    ]

    if combo.shortcut == .init(.tab, modifiers: [.command]), HotkeyOverrideState().isCmdTabEnabled {
      return
    }

    if additionalSystemConflicts.contains(combo.shortcut) {
      throw HotkeyRegistrationError.systemConflict(combo)
    }
  }

  private func createUniqueShortcutName() -> KeyboardShortcuts.Name {
    let id = nextShortcutId.modify { current in
      let newId = current + 1
      return newId
    }

    // Use predefined extension names
    switch id {
    case 1: return .showHideAltSwitch
    default: return KeyboardShortcuts.Name("dynamicHotkey\(id)")
    }
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func keyFromCode(_ keyCode: UInt16) -> KeyboardShortcuts.Key? {
    // Map common key codes to KeyboardShortcuts.Key
    switch keyCode {
    case 49: return .space
    case 36: return .return
    case 53: return .escape
    case 51: return .delete
    case 48: return .tab
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
    case 47: return .period
    default: return nil
    }
  }
}

// MARK: - Thread-Safe Box

private final class SendableBox<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: T

  init(_ value: T) {
    _value = value
  }

  var value: T {
    get {
      lock.withLock { _value }
    }
    set {
      lock.withLock { _value = newValue }
    }
  }

  func modify<U>(_ transform: (inout T) -> U) -> U {
    lock.withLock {
      transform(&_value)
    }
  }
}

extension SendableBox where T: ExpressibleByNilLiteral {
  convenience init() {
    self.init(nil)
  }
}
