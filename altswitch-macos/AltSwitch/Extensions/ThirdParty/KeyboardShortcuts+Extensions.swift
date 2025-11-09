//
//  KeyboardShortcuts+Extensions.swift
//  AltSwitch
//
//  Extensions for KeyboardShortcuts framework to define custom shortcut names
//

import AppKit
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  /// Global hotkey to show/hide the AltSwitch window
  static let showHideAltSwitch = Self(
    "showHideAltSwitch", default: .init(.a, modifiers: [.command, .shift]))

  /// Alternative Alt+Tab shortcut for show/hide (when enabled by user)
  static let altTabShowHide = Self("altTabShowHide", default: nil)

  /// Alternative Cmd+Tab shortcut for show/hide (when enabled by user)
  static let cmdTabShowHide = Self("cmdTabShowHide", default: nil)
}

// MARK: - Convenience Extensions

extension KeyboardShortcuts.Name {
  /// Returns the display name for this shortcut
  var displayName: String {
    switch self {
    case .showHideAltSwitch:
      return "Show/Hide AltSwitch"
    case .altTabShowHide:
      return "Alt+Tab Show/Hide"
    case .cmdTabShowHide:
      return "Cmd+Tab Show/Hide"
    default:
      return rawValue
    }
  }

  /// Returns a description of what this shortcut does
  var description: String {
    switch self {
    case .showHideAltSwitch:
      return "Toggles the AltSwitch window visibility for app switching"
    case .altTabShowHide:
      return "Alternative Alt+Tab shortcut for app switching (replaces system default)"
    case .cmdTabShowHide:
      return "Alternative Cmd+Tab shortcut for app switching (replaces system default)"
    default:
      return "Custom keyboard shortcut"
    }
  }
}

// MARK: - Validation Helpers

extension KeyboardShortcuts.Name {
  /// Validates that the shortcut is appropriate for system-wide use
  var isValidForGlobalUse: Bool {
    // Check if this shortcut conflicts with common system shortcuts
    guard let shortcut = KeyboardShortcuts.getShortcut(for: self) else { return true }

    // Avoid conflicts with common system shortcuts (except Alt+Tab which we want to override)
    let conflictingCombinations: [KeyboardShortcuts.Shortcut] = [
      .init(.space, modifiers: [.command]),  // Cmd+Space (Spotlight)
      .init(.escape, modifiers: []),  // Escape key
      .init(.return, modifiers: []),  // Return key
    ]

    // Allow Alt+Tab and Cmd+Tab for our special shortcuts specifically
    if self == .altTabShowHide || self == .cmdTabShowHide {
      return true
    }

    // Still block Cmd+Tab for other shortcuts
    if shortcut == .init(.tab, modifiers: [.command]) {
      return false
    }

    return !conflictingCombinations.contains(shortcut)
  }
}
