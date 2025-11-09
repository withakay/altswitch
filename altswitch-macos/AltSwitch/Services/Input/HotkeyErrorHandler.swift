//
//  HotkeyErrorHandler.swift
//  AltSwitch
//
//  Centralized error handling for hotkey registration conflicts
//  Provides user-friendly error messages and conflict resolution strategies
//

import AppKit
import Combine
import Foundation
import KeyboardShortcuts

/// Centralized error handling for hotkey registration conflicts
@MainActor
final class HotkeyErrorHandler: ObservableObject {

  // MARK: - Error Types

  /// Specific hotkey registration errors
  enum HotkeyError: Error, LocalizedError {
    case shortcutInUse(KeyCombo, conflictingApp: String?)
    case invalidShortcut(KeyCombo, reason: String)
    case systemConflict(KeyCombo, systemFunction: String)
    case registrationTimeout(KeyCombo)
    case unknownError(KeyCombo, underlying: Error)

    var errorDescription: String? {
      switch self {
      case .shortcutInUse(let combo, let app):
        if let app = app {
          return "Shortcut \(combo.displayString) is already in use by \(app)"
        } else {
          return "Shortcut \(combo.displayString) is already in use by another application"
        }
      case .invalidShortcut(let combo, let reason):
        return "Invalid shortcut \(combo.displayString): \(reason)"
      case .systemConflict(let combo, let function):
        return "Shortcut \(combo.displayString) conflicts with system function: \(function)"
      case .registrationTimeout(let combo):
        return "Timeout registering shortcut \(combo.displayString)"
      case .unknownError(let combo, let error):
        return "Failed to register shortcut \(combo.displayString): \(error.localizedDescription)"
      }
    }

    var recoverySuggestion: String? {
      switch self {
      case .shortcutInUse:
        return
          "Try using a different key combination or check if the conflicting application can change its shortcut."
      case .invalidShortcut:
        return "Use a combination with at least one modifier key (⌘, ⌥, ⌃) and a valid key."
      case .systemConflict:
        return "Choose a different key combination that doesn't conflict with system functions."
      case .registrationTimeout:
        return "Try again or restart the application if the issue persists."
      case .unknownError:
        return "Check system permissions and try a different key combination."
      }
    }

    var failureReason: String? {
      switch self {
      case .shortcutInUse:
        return "Hotkey conflict"
      case .invalidShortcut:
        return "Invalid key combination"
      case .systemConflict:
        return "System shortcut conflict"
      case .registrationTimeout:
        return "Registration timeout"
      case .unknownError:
        return "Unknown registration error"
      }
    }
  }

  // MARK: - Properties

  /// Current error being displayed
  @Published var currentError: HotkeyError?

  /// Error display duration
  private let errorDisplayDuration: TimeInterval = 5.0

  /// Timer for auto-dismissing errors
  private var errorDismissalTimer: Timer?

  // MARK: - Alternative Suggestions

  /// Generates alternative shortcut suggestions when a conflict occurs
  func suggestAlternatives(for conflictedCombo: KeyCombo) -> [KeyCombo] {
    var suggestions: [KeyCombo] = []

    // Try different modifier combinations with the same key
    if let key = conflictedCombo.shortcut.key {
      let alternativeModifiers: [NSEvent.ModifierFlags] = [
        [.command, .option],
        [.command, .shift],
        [.command, .control],
        [.option, .shift],
        [.control, .shift],
        [.command, .option, .shift],
        [.command, .control, .shift],
      ]

      for modifiers in alternativeModifiers {
        if modifiers != conflictedCombo.shortcut.modifiers {
          let newShortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
          let newCombo = KeyCombo(shortcut: newShortcut, description: conflictedCombo.description)
          if newCombo.isValid && !newCombo.hasSystemConflict {
            suggestions.append(newCombo)
          }
        }
      }
    }

    // Try common alternative keys with the same modifiers
    let alternativeKeys: [KeyboardShortcuts.Key] = [
      .space, .t, .f13, .f14, .f15, .f16, .f17, .f18,
    ]

    for key in alternativeKeys {
      if key != conflictedCombo.shortcut.key {
        let newShortcut = KeyboardShortcuts.Shortcut(
          key, modifiers: conflictedCombo.shortcut.modifiers)
        let newCombo = KeyCombo(shortcut: newShortcut, description: conflictedCombo.description)
        if newCombo.isValid && !newCombo.hasSystemConflict {
          suggestions.append(newCombo)
        }
      }
    }

    // Return top 3 suggestions
    return Array(suggestions.prefix(3))
  }

  // MARK: - Conflict Detection

  /// Detects what application might be using a shortcut
  func detectConflictingApp(for combo: KeyCombo) -> String? {
    // Check common applications that might use shortcuts
    let commonApps = [
      "Spotlight": KeyCombo(shortcut: .init(.space, modifiers: [.command]), description: ""),
      "Mission Control": KeyCombo(
        shortcut: .init(.upArrow, modifiers: [.control]), description: ""),
      "Application Windows": KeyCombo(
        shortcut: .init(.downArrow, modifiers: [.control]), description: ""),
      "Desktop": KeyCombo(shortcut: .init(.f11, modifiers: []), description: ""),
    ]

    for (appName, appCombo) in commonApps {
      if appCombo.shortcut == combo.shortcut {
        return appName
      }
    }

    // For a production app, you might query running applications
    // and their registered shortcuts using private APIs or heuristics
    return nil
  }

  // MARK: - Error Handling

  /// Handles a hotkey registration error with user-friendly messaging
  func handleError(_ error: Error, for combo: KeyCombo) {
    let hotkeyError: HotkeyError

    if let existingError = error as? HotkeyError {
      hotkeyError = existingError
    } else if error.localizedDescription.contains("already in use")
      || error.localizedDescription.contains("conflict")
    {
      let conflictingApp = detectConflictingApp(for: combo)
      hotkeyError = .shortcutInUse(combo, conflictingApp: conflictingApp)
    } else if combo.hasSystemConflict {
      let systemFunction = getSystemFunction(for: combo)
      hotkeyError = .systemConflict(combo, systemFunction: systemFunction)
    } else if !combo.isValid {
      let reason = getInvalidReason(for: combo)
      hotkeyError = .invalidShortcut(combo, reason: reason)
    } else {
      hotkeyError = .unknownError(combo, underlying: error)
    }

    presentError(hotkeyError)
  }

  /// Validates a shortcut before attempting registration
  func validateShortcut(_ combo: KeyCombo) throws {
    // Check if shortcut is valid
    guard combo.isValid else {
      let reason = getInvalidReason(for: combo)
      throw HotkeyError.invalidShortcut(combo, reason: reason)
    }

    // Check for system conflicts
    if combo.hasSystemConflict {
      let systemFunction = getSystemFunction(for: combo)
      throw HotkeyError.systemConflict(combo, systemFunction: systemFunction)
    }
  }

  /// Presents an error to the user with auto-dismissal
  func presentError(_ error: HotkeyError) {
    currentError = error

    // Auto-dismiss after timeout
    errorDismissalTimer?.invalidate()
    errorDismissalTimer = Timer.scheduledTimer(
      withTimeInterval: errorDisplayDuration, repeats: false
    ) { _ in
      Task { @MainActor in
        self.dismissError()
      }
    }

    // Log error for debugging
    print("HotkeyErrorHandler: \(error.localizedDescription)")
  }

  /// Dismisses the current error
  func dismissError() {
    currentError = nil
    errorDismissalTimer?.invalidate()
    errorDismissalTimer = nil
  }

  // MARK: - Recovery Actions

  /// Attempts to register a hotkey with automatic conflict resolution
  func registerWithConflictResolution(
    _ combo: KeyCombo,
    registrationHandler: @escaping (KeyCombo) async throws -> Void
  ) async -> KeyCombo? {
    // First, try the original shortcut
    do {
      try validateShortcut(combo)
      try await registrationHandler(combo)
      return combo
    } catch {
      handleError(error, for: combo)
    }

    // If that fails, try alternatives
    let alternatives = suggestAlternatives(for: combo)

    for alternative in alternatives {
      do {
        try validateShortcut(alternative)
        try await registrationHandler(alternative)

        // Success with alternative
        dismissError()
        return alternative
      } catch {
        // Continue to next alternative
        continue
      }
    }

    // All alternatives failed
    return nil
  }

  // MARK: - Private Helpers

  private func getSystemFunction(for combo: KeyCombo) -> String {
    switch combo.shortcut {
    case .init(.tab, modifiers: [.command]):
      return "Application Switcher"
    case .init(.space, modifiers: [.command]):
      return "Spotlight Search"
    case .init(.q, modifiers: [.command]):
      return "Quit Application"
    case .init(.w, modifiers: [.command]):
      return "Close Window"
    case .init(.h, modifiers: [.command]):
      return "Hide Application"
    default:
      return "System Function"
    }
  }

  private func getInvalidReason(for combo: KeyCombo) -> String {
    let meaningfulModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
    if combo.shortcut.modifiers.intersection(meaningfulModifiers).isEmpty {
      return "Must include at least one modifier key (⌘, ⌥, or ⌃)"
    }

    if combo.shortcut.key == nil {
      return "Invalid key"
    }

    return "Unknown validation issue"
  }

}

// MARK: - Error Recovery Extensions

extension HotkeyErrorHandler {

  /// Convenience method for handling KeyboardShortcuts framework errors
  func handleKeyboardShortcutsError(_ error: Error, for combo: KeyCombo) {
    // KeyboardShortcuts framework specific error handling
    if error.localizedDescription.contains("shortcut is already taken") {
      let conflictingApp = detectConflictingApp(for: combo)
      presentError(.shortcutInUse(combo, conflictingApp: conflictingApp))
    } else {
      handleError(error, for: combo)
    }
  }

  /// Checks if a shortcut is likely to work before registration
  func canRegister(_ combo: KeyCombo) -> Bool {
    do {
      try validateShortcut(combo)
      return true
    } catch {
      return false
    }
  }

  /// Gets a user-friendly error message for display in UI
  func getDisplayMessage(for error: HotkeyError) -> (
    title: String, message: String, suggestions: [KeyCombo]
  ) {
    let title: String
    let message: String

    switch error {
    case .shortcutInUse(let combo, let app):
      title = "Shortcut Conflict"
      if let app = app {
        message = "The shortcut \(combo.displayString) is already used by \(app)."
      } else {
        message = "The shortcut \(combo.displayString) is already in use."
      }

    case .invalidShortcut(let combo, let reason):
      title = "Invalid Shortcut"
      message = "The shortcut \(combo.displayString) is invalid: \(reason)"

    case .systemConflict(let combo, let function):
      title = "System Conflict"
      message = "The shortcut \(combo.displayString) conflicts with \(function)."

    case .registrationTimeout(let combo):
      title = "Registration Timeout"
      message = "Failed to register \(combo.displayString) within the time limit."

    case .unknownError(let combo, let underlying):
      title = "Registration Error"
      message = "Failed to register \(combo.displayString): \(underlying.localizedDescription)"
    }

    let suggestions = suggestAlternatives(for: error.keyCombo)
    return (title, message, suggestions)
  }
}

// MARK: - HotkeyError Extensions

extension HotkeyErrorHandler.HotkeyError {
  fileprivate var keyCombo: KeyCombo {
    switch self {
    case .shortcutInUse(let combo, _),
      .invalidShortcut(let combo, _),
      .systemConflict(let combo, _),
      .registrationTimeout(let combo),
      .unknownError(let combo, _):
      return combo
    }
  }
}
