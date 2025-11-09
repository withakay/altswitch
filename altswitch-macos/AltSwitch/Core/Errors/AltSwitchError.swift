//
//  AltSwitchError.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import CoreGraphics
import Foundation

/// Custom error types for the AltSwitch application
enum AltSwitchError: Error, LocalizedError {
  case accessibilityPermissionDenied
  case appNotFound(bundleID: String)
  case windowNotFound(windowID: CGWindowID)
  case hotkeyRegistrationFailed(KeyCombo)
  case appDiscoveryFailed(underlying: Error)

  var errorDescription: String? {
    switch self {
    case .accessibilityPermissionDenied:
      return
        "Accessibility permission required. Please grant access in System Settings > Privacy & Security > Accessibility."
    case .appNotFound(let bundleID):
      return "Application not found: \(bundleID)"
    case .windowNotFound(let windowID):
      return "Window not found: \(windowID)"
    case .hotkeyRegistrationFailed:
      return "Failed to register hotkey. It may be in use by another application."
    case .appDiscoveryFailed(let error):
      return "Failed to discover applications: \(error.localizedDescription)"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .accessibilityPermissionDenied:
      return
        "Open System Settings and enable AltSwitch in Privacy & Security > Accessibility, then restart the app."
    case .appNotFound:
      return "The application may have been closed. Try refreshing the app list."
    case .windowNotFound:
      return "The window may have been closed. Try refreshing the window list."
    case .hotkeyRegistrationFailed:
      return "Try using a different keyboard shortcut combination in Settings."
    case .appDiscoveryFailed:
      return "Check that you have the necessary permissions and try again."
    }
  }

  var failureReason: String? {
    switch self {
    case .accessibilityPermissionDenied:
      return "Missing required system permission"
    case .appNotFound:
      return "Application is not running"
    case .windowNotFound:
      return "Window is not available"
    case .hotkeyRegistrationFailed:
      return "Hotkey conflict"
    case .appDiscoveryFailed:
      return "System API failure"
    }
  }
}
