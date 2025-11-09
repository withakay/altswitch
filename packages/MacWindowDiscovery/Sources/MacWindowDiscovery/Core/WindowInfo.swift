import Foundation
import CoreGraphics
import ApplicationServices

/// Comprehensive metadata about a macOS window
///
/// This struct is Sendable, Codable, and fully self-contained.
/// It does not hold references to platform objects (NSRunningApplication, AXUIElement).
///
/// **Memory Footprint:** Approximately 250-400 bytes per instance including heap allocations.
/// This keeps memory usage reasonable even with hundreds of windows cached.
public struct WindowInfo: Sendable, Codable, Identifiable, Hashable {
    // MARK: - Core Properties

    /// Unique window identifier from CGWindowList
    public let id: CGWindowID

    /// Window title (may be empty for some windows)
    public let title: String

    /// Window bounds in screen coordinates
    public let bounds: CGRect

    /// Alpha transparency (0.0 = fully transparent, 1.0 = fully opaque)
    public let alpha: Double

    /// Whether the window is currently on screen
    public let isOnScreen: Bool

    /// Window layer (0 = normal, higher = floating/overlay)
    public let layer: Int

    // MARK: - Application Properties

    /// Process ID of the owning application
    public let processID: pid_t

    /// Bundle identifier of the owning application
    public let bundleIdentifier: String?

    /// Localized application name
    public let applicationName: String?

    // MARK: - State Properties

    /// Whether the window is minimized (from AX API)
    public let isMinimized: Bool

    /// Whether the window is hidden (from AX API)
    public let isHidden: Bool

    /// Whether the window is fullscreen (from AX API)
    public let isFullscreen: Bool

    /// Whether the window is the focused window for its app (from AX API)
    public let isFocused: Bool

    /// Whether the window is the main window for its app (from AX API)
    public let isMainWindow: Bool

    /// Whether the window is tabbed (part of a tab group, from AX API)
    public let isTabbed: Bool

    // MARK: - Spaces Properties

    /// Space IDs where this window appears
    public let spaceIDs: [Int]

    /// Whether the window appears on all Spaces
    public let isOnAllSpaces: Bool

    /// User-friendly desktop number (1-indexed) as shown in Mission Control
    /// - nil if the desktop number cannot be determined
    /// - Desktop 1, Desktop 2, etc. correspond to the order in Mission Control
    public let desktopNumber: Int?

    // MARK: - Display Properties

    /// Display ID where this window is primarily located
    public let displayID: CGDirectDisplayID

    // MARK: - Metadata

    /// Window role from AX API (e.g., "AXWindow")
    public let role: String?

    /// Window subrole from AX API (e.g., "AXStandardWindow", "AXDialog")
    public let subrole: String?

    /// When this information was captured
    public let capturedAt: Date

    // MARK: - Initialization

    public init(
        id: CGWindowID,
        title: String,
        bounds: CGRect,
        alpha: Double,
        isOnScreen: Bool,
        layer: Int,
        processID: pid_t,
        bundleIdentifier: String?,
        applicationName: String?,
        isMinimized: Bool,
        isHidden: Bool,
        isFullscreen: Bool,
        isFocused: Bool,
        isMainWindow: Bool,
        isTabbed: Bool,
        spaceIDs: [Int],
        isOnAllSpaces: Bool,
        desktopNumber: Int?,
        displayID: CGDirectDisplayID,
        role: String?,
        subrole: String?,
        capturedAt: Date
    ) {
        self.id = id
        self.title = title
        self.bounds = bounds
        self.alpha = alpha
        self.isOnScreen = isOnScreen
        self.layer = layer
        self.processID = processID
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.isMinimized = isMinimized
        self.isHidden = isHidden
        self.isFullscreen = isFullscreen
        self.isFocused = isFocused
        self.isMainWindow = isMainWindow
        self.isTabbed = isTabbed
        self.spaceIDs = spaceIDs
        self.isOnAllSpaces = isOnAllSpaces
        self.desktopNumber = desktopNumber
        self.displayID = displayID
        self.role = role
        self.subrole = subrole
        self.capturedAt = capturedAt
    }
}

// MARK: - Hashable & Equatable

extension WindowInfo {
    public func hash(into hasher: inout Hasher) {
        // Only hash the unique identifier
        hasher.combine(id)
    }

    public static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        // Windows are equal if they have the same ID
        lhs.id == rhs.id
    }
}

// MARK: - Convenience Properties

extension WindowInfo {
    /// Human-readable display name combining title and app name
    public var displayName: String {
        if !title.isEmpty {
            return title
        }
        return applicationName ?? bundleIdentifier ?? "Unknown Window"
    }

    /// Whether this is a standard window (vs. utility/panel)
    public var isStandardWindow: Bool {
        subrole == "AXStandardWindow" || subrole == "AXDialog"
    }
}
