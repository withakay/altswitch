//
//  WindowActivator.swift
//  MacWindowSwitch
//
//  Public API for window activation
//

import AppKit
@preconcurrency import ApplicationServices
import Foundation

/// Main entry point for window activation
///
/// WindowActivator provides a simple, async API for activating windows on macOS,
/// including cross-space and cross-display activation capabilities.
///
/// **Example:**
/// ```swift
/// try WindowActivator.activate(windowID: 12345, processID: 67890)
/// ```
///
/// **Requirements:**
/// - Accessibility permissions must be granted
/// - Application must not be sandboxed
/// - macOS 13.0+
public struct WindowActivator {

    // MARK: - Public API

    /// Activate a window by its CGWindowID and owner PID
    ///
    /// This is a synchronous, fire-and-forget activation that matches the behavior
    /// of alt-tab-macos. The activation happens on a background queue and this method
    /// returns immediately.
    ///
    /// - Parameters:
    ///   - windowID: The Core Graphics window ID
    ///   - processID: The process ID that owns the window
    /// - Throws: WindowActivationError.accessibilityPermissionDenied if permissions not granted
    ///
    /// **Behavior:**
    /// - Switches to window's space if on different space
    /// - Activates window across displays
    /// - Makes window key within its application
    /// - Returns immediately (operation continues in background)
    ///
    /// **Logging:**
    /// All activation operations are logged using NSLog for parity testing with alt-tab-macos.
    public static func activate(windowID: CGWindowID, processID: pid_t) throws {
        // Check accessibility permissions first
        guard hasAccessibilityPermission() else {
            throw WindowActivationError.accessibilityPermissionDenied
        }

        // Log activation for parity comparison with alt-tab-macos
        NSLog("MacWindowSwitch: Activating window \(windowID) for process \(processID)")

        // Delegate to the activation engine (fire-and-forget)
        WindowActivationEngine.activate(windowID: windowID, processID: processID)
    }

    /// Activate a window by its CGWindowID only, using injected resolvers for PID and AX.
    /// If PID cannot be resolved, the activation is skipped.
    public static func activate(windowID: CGWindowID, dependencies: ActivationDependencies? = nil) throws {
        guard hasAccessibilityPermission() else {
            throw WindowActivationError.accessibilityPermissionDenied
        }
        NSLog("MacWindowSwitch: Activating window \(windowID) using dependencies")
        WindowActivationEngine.activate(windowID: windowID, dependencies: dependencies)
    }

    /// Activate an application by process ID
    ///
    /// This activates the application, bringing all its windows to front.
    /// For windowless applications (menu bar apps), this makes the app active.
    ///
    /// - Parameter processID: The process ID to activate
    /// - Throws: WindowActivationError if activation fails
    public static func activateApplication(processID: pid_t) throws {
        // Check accessibility permissions first
        guard hasAccessibilityPermission() else {
            throw WindowActivationError.accessibilityPermissionDenied
        }

        // Log activation
        NSLog("MacWindowSwitch: Activating application with process \(processID)")

        // Use NSRunningApplication for simple app activation
        guard let app = NSRunningApplication(processIdentifier: processID) else {
            throw WindowActivationError.invalidProcessID(processID)
        }

        // Activate with all windows
        let activated = app.activate(options: .activateAllWindows)
        guard activated else {
            throw WindowActivationError.cannotActivate(0, reason: "NSRunningApplication.activate() returned false")
        }
    }

    // MARK: - Permission Checking

    /// Check if Accessibility permission is granted
    ///
    /// - Returns: true if Accessibility permission is granted, false otherwise
    private static func hasAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request Accessibility permission (opens System Settings)
    ///
    /// This will prompt the user to grant Accessibility permission by opening
    /// System Settings to the appropriate pane.
    public static func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
