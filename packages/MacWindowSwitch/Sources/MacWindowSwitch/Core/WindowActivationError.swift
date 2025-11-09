//
//  WindowActivationError.swift
//  MacWindowSwitch
//
//  Error types for window activation failures
//

import CoreGraphics
import Foundation

/// Errors that can occur during window activation
public enum WindowActivationError: Error, LocalizedError, Sendable {

    /// The window ID is invalid or doesn't exist
    case invalidWindowID(CGWindowID)

    /// The process ID is invalid or not running
    case invalidProcessID(pid_t)

    /// Accessibility permissions not granted
    case accessibilityPermissionDenied

    /// Window activation timed out (app may be unresponsive)
    case timeout(CGWindowID, duration: TimeInterval)

    /// The window cannot be activated (e.g., minimized, hidden)
    case cannotActivate(CGWindowID, reason: String)

    /// Unknown error from the system
    case systemError(OSStatus)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .invalidWindowID(let wid):
            return "Invalid window ID: \(wid)"
        case .invalidProcessID(let pid):
            return "Invalid process ID: \(pid)"
        case .accessibilityPermissionDenied:
            return "Accessibility permission required. Grant in System Settings > Privacy & Security > Accessibility"
        case .timeout(let wid, let duration):
            return "Window activation timed out after \(duration)s for window \(wid)"
        case .cannotActivate(let wid, let reason):
            return "Cannot activate window \(wid): \(reason)"
        case .systemError(let status):
            return "System error: \(status)"
        }
    }
}
