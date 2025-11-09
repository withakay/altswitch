//
//  MacWindowSwitch.swift
//  MacWindowSwitch
//
//  Main module file for MacWindowSwitch package
//

import Foundation

/// MacWindowSwitch provides reliable window activation on macOS with cross-space support.
///
/// This package enables activating windows across different Spaces and displays using
/// private macOS APIs that provide functionality not available through public frameworks.
///
/// **Example Usage:**
/// ```swift
/// try await WindowActivator.activate(windowID: 12345, processID: 67890)
/// ```
///
/// **Requirements:**
/// - macOS 13.0+
/// - Accessibility permissions
/// - Non-sandboxed application
public struct MacWindowSwitch {
    /// Package version
    public static let version = "0.1.0-alpha"

    /// Minimum supported macOS version
    public static let minimumMacOSVersion = "13.0"
}
