//
//  AppSwitcherProtocol.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import Foundation

/// Protocol for switching to and managing applications
protocol AppSwitcherProtocol: Sendable {
  /// Switch to the specified application and bring it to front
  /// - Parameter app: The application to switch to
  /// - Throws: AppSwitchError if the operation fails
  func switchTo(_ app: AppInfo) async throws

  /// Bring the specified application to the front without activating it
  /// - Parameter app: The application to bring to front
  /// - Throws: AppSwitchError if the operation fails
  func bringToFront(_ app: AppInfo) async throws

  /// Unhide a hidden application
  /// - Parameter app: The application to unhide
  /// - Throws: AppSwitchError if the operation fails
  func unhide(_ app: AppInfo) async throws
}

/// Errors that can occur during app switching operations
enum AppSwitchError: Error, LocalizedError, Sendable {
  case accessibilityDenied
  case appNotFound
  case appNotRunning
  case operationFailed(String)
  case timeout

  var errorDescription: String? {
    switch self {
    case .accessibilityDenied:
      return "Accessibility permission denied"
    case .appNotFound:
      return "Application not found"
    case .appNotRunning:
      return "Application is not running"
    case .operationFailed(let message):
      return "Operation failed: \(message)"
    case .timeout:
      return "Operation timed out"
    }
  }

  var recoverySuggestion: String? {
    switch self {
    case .accessibilityDenied:
      return "Please grant accessibility permissions in System Settings"
    case .appNotFound:
      return "Please check if the application is running"
    case .appNotRunning:
      return "Please start the application first"
    case .operationFailed:
      return "Please try again or check system logs"
    case .timeout:
      return "Please try again with a longer timeout"
    }
  }
}
