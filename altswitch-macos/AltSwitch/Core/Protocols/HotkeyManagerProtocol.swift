//
//  HotkeyManagerProtocol.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import AppKit
import Foundation

/// Enhanced protocol for managing global hotkeys with KeyCombo support
protocol HotkeyManagerProtocol: Sendable {
  /// Whether a global hotkey is currently registered (legacy support)
  var isRegistered: Bool { get }

  // MARK: - Enhanced Methods (KeyCombo-based)

  /// Register a global hotkey with KeyCombo and async action
  /// - Parameters:
  ///   - combo: The key combination to register
  ///   - action: The async action to execute when the hotkey is pressed
  /// - Throws: HotkeyRegistrationError if registration fails
  func registerHotkey(_ combo: KeyCombo, action: @escaping @Sendable () -> Void) async throws

  /// Unregister a specific hotkey
  /// - Parameter combo: The key combination to unregister
  /// - Throws: HotkeyRegistrationError if unregistration fails
  func unregisterHotkey(_ combo: KeyCombo) async throws

  /// Check if a specific hotkey is currently registered
  /// - Parameter combo: The key combination to check
  /// - Returns: True if the hotkey is registered
  func isHotkeyRegistered(_ combo: KeyCombo) -> Bool

  /// Get all currently registered hotkeys
  /// - Returns: Array of registered key combinations
  func getRegisteredHotkeys() -> [KeyCombo]

  /// Enable or disable all hotkeys globally
  /// - Parameter enabled: Whether hotkeys should be enabled
  func setHotkeysEnabled(_ enabled: Bool) async

  // MARK: - Legacy Methods (backward compatibility)

  /// Register a global hotkey combination (legacy)
  /// - Parameters:
  ///   - keyCode: The key code for the hotkey
  ///   - modifiers: The modifier flags (cmd, option, shift, control)
  ///   - handler: The closure to execute when the hotkey is pressed
  /// - Throws: HotkeyError if registration fails
  func register(
    keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags,
    handler: @escaping @Sendable () -> Void
  ) async throws

  /// Unregister the currently registered global hotkey (legacy)
  func unregister() async
}

/// Legacy errors that can occur during hotkey operations (backward compatibility)
enum HotkeyError: Error, Sendable {
  case registrationFailed(String)
  case alreadyRegistered
  case noHotkeyRegistered
  case systemPermissionDenied
}
