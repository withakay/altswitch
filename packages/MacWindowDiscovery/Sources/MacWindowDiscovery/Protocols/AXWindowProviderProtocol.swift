import Foundation
import CoreGraphics

/// Window state information from Accessibility API
public struct AXWindowInfo: Sendable, Equatable {
    /// Whether the window is minimized
    public let isMinimized: Bool

    /// Whether the window is hidden
    public let isHidden: Bool

    /// Whether the window is fullscreen
    public let isFullscreen: Bool

    /// Whether the window is focused for its application
    public let isFocused: Bool

    /// Whether the window is the main window for its application
    public let isMainWindow: Bool

    /// Whether the window is tabbed (part of a tab group but not the active tab)
    public let isTabbed: Bool

    /// Window title from AX API (may differ from CG title)
    public let title: String?

    /// Window role (e.g., "AXWindow")
    public let role: String?

    /// Window subrole (e.g., "AXStandardWindow", "AXDialog")
    public let subrole: String?

    public init(
        isMinimized: Bool = false,
        isHidden: Bool = false,
        isFullscreen: Bool = false,
        isFocused: Bool = false,
        isMainWindow: Bool = false,
        isTabbed: Bool = false,
        title: String? = nil,
        role: String? = nil,
        subrole: String? = nil
    ) {
        self.isMinimized = isMinimized
        self.isHidden = isHidden
        self.isFullscreen = isFullscreen
        self.isFocused = isFocused
        self.isMainWindow = isMainWindow
        self.isTabbed = isTabbed
        self.title = title
        self.role = role
        self.subrole = subrole
    }
}

/// Protocol for Accessibility API providers
public protocol AXWindowProviderProtocol: Sendable {
    /// Build a lookup table of window state for an application
    ///
    /// Queries the Accessibility API for window state information.
    /// Returns empty dictionary if permissions are not granted.
    ///
    /// - Parameters:
    ///   - pid: Process ID of the application
    ///   - bundleIdentifier: Bundle identifier for logging
    /// - Returns: Dictionary mapping CGWindowID to AXWindowInfo
    nonisolated func buildWindowLookup(
        for pid: pid_t,
        bundleIdentifier: String
    ) -> [CGWindowID: AXWindowInfo]
}
