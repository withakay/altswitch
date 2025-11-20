import Foundation
import CoreGraphics

/// Options for configuring window discovery behavior
public struct WindowDiscoveryOptions: Sendable, Equatable, Hashable {
    // MARK: - Filtering Options

    /// Minimum window size to include (default: 100x50)
    public var minimumSize: CGSize

    /// Include only layer 0 windows (default: true)
    public var normalLayerOnly: Bool

    /// Minimum alpha threshold (default: 0.9)
    public var minimumAlpha: Double

    /// Include hidden windows (default: false)
    public var includeHidden: Bool

    /// Include minimized windows (default: true)
    public var includeMinimized: Bool

    /// Include windows on inactive Spaces (default: true)
    public var includeInactiveSpaces: Bool

    /// Require windows to have a title (default: false)
    /// Windows without titles are typically system UI elements or windows on inactive spaces
    public var requireTitle: Bool

    /// Require windows to have proper AX subrole (default: true)
    /// Windows without proper subrole are typically hidden/system windows
    /// Valid subroles: AXStandardWindow, AXDialog
    public var requireProperSubrole: Bool

    // MARK: - Application Filtering

    /// Only include windows from these bundle IDs (nil = all)
    public var bundleIdentifierWhitelist: Set<String>?

    /// Exclude windows from these bundle IDs
    public var bundleIdentifierBlacklist: Set<String>

    /// Exclude system processes (dock, control center, etc.)
    public var excludeSystemProcesses: Bool

    /// Application names to exclude completely (all windows)
    /// Matches against the localized application name
    public var applicationNameExcludeList: Set<String>

    /// Application names to exclude only untitled windows from
    /// Matches against the localized application name
    /// Only excludes windows where title is empty
    public var untitledWindowExcludeList: Set<String>

    // MARK: - Performance Options

    /// Whether to enrich with AX metadata (slower but more accurate)
    public var useAccessibilityAPI: Bool

    /// Whether to include Space information (requires private APIs)
    public var includeSpaceInfo: Bool
    
    /// Whether to enable AX element caching for cross-space window switching
    public var enableAXElementCaching: Bool
    
    /// Whether to collect AX title overlay for windows with empty CG titles
    public var collectTitleOverlay: Bool

    // MARK: - Initialization

    public init(
        minimumSize: CGSize = CGSize(width: 100, height: 50),
        normalLayerOnly: Bool = true,
        minimumAlpha: Double = 0.9,
        includeHidden: Bool = false,
        includeMinimized: Bool = true,
        includeInactiveSpaces: Bool = true,
        requireTitle: Bool = false,
        requireProperSubrole: Bool = true,
        bundleIdentifierWhitelist: Set<String>? = nil,
        bundleIdentifierBlacklist: Set<String> = [],
        excludeSystemProcesses: Bool = true,
        applicationNameExcludeList: Set<String> = [],
        untitledWindowExcludeList: Set<String> = [],
        useAccessibilityAPI: Bool = true,
        includeSpaceInfo: Bool = true,
        enableAXElementCaching: Bool = false,
        collectTitleOverlay: Bool = false
    ) {
        self.minimumSize = minimumSize
        self.normalLayerOnly = normalLayerOnly
        self.minimumAlpha = minimumAlpha
        self.includeHidden = includeHidden
        self.includeMinimized = includeMinimized
        self.includeInactiveSpaces = includeInactiveSpaces
        self.requireTitle = requireTitle
        self.requireProperSubrole = requireProperSubrole
        self.bundleIdentifierWhitelist = bundleIdentifierWhitelist
        self.bundleIdentifierBlacklist = bundleIdentifierBlacklist
        self.excludeSystemProcesses = excludeSystemProcesses
        self.applicationNameExcludeList = applicationNameExcludeList
        self.untitledWindowExcludeList = untitledWindowExcludeList
        self.useAccessibilityAPI = useAccessibilityAPI
        self.includeSpaceInfo = includeSpaceInfo
        self.enableAXElementCaching = enableAXElementCaching
        self.collectTitleOverlay = collectTitleOverlay
    }
}

// MARK: - Presets

extension WindowDiscoveryOptions {
    /// Default options: standard windows only, full metadata
    public static let `default` = WindowDiscoveryOptions(
        minimumSize: CGSize(width: 100, height: 50),
        normalLayerOnly: true,
        minimumAlpha: 0.9,
        includeHidden: false,
        includeMinimized: true,
        includeInactiveSpaces: true,
        requireTitle: false,  // Allow windows without titles (will use app name fallback)
        requireProperSubrole: true,  // Require proper AX subrole
        bundleIdentifierWhitelist: nil,
        bundleIdentifierBlacklist: [],
        excludeSystemProcesses: true,
        applicationNameExcludeList: [],
        untitledWindowExcludeList: [],
        useAccessibilityAPI: true,
        includeSpaceInfo: true
    )

    /// Fast preset: minimal filtering, no AX enrichment
    public static let fast = WindowDiscoveryOptions(
        minimumSize: CGSize(width: 50, height: 25),
        normalLayerOnly: false,
        minimumAlpha: 0.5,
        includeHidden: true,
        includeMinimized: true,
        includeInactiveSpaces: true,
        requireTitle: false,
        requireProperSubrole: false,  // No AX, so can't require subrole
        bundleIdentifierWhitelist: nil,
        bundleIdentifierBlacklist: [],
        excludeSystemProcesses: false,
        applicationNameExcludeList: [],
        untitledWindowExcludeList: [],
        useAccessibilityAPI: false,  // Key difference: no AX
        includeSpaceInfo: false
    )

    /// Complete preset: all windows, full metadata
    public static let complete = WindowDiscoveryOptions(
        minimumSize: .zero,
        normalLayerOnly: false,
        minimumAlpha: 0.0,
        includeHidden: true,
        includeMinimized: true,
        includeInactiveSpaces: true,
        requireTitle: false,
        requireProperSubrole: false,  // Show all windows
        bundleIdentifierWhitelist: nil,
        bundleIdentifierBlacklist: [],
        excludeSystemProcesses: false,
        applicationNameExcludeList: [],
        untitledWindowExcludeList: [],
        useAccessibilityAPI: true,
        includeSpaceInfo: true
    )

    /// CLI preset: human-readable filtering for command-line usage
    public static let cli = WindowDiscoveryOptions(
        minimumSize: CGSize(width: 100, height: 50),
        normalLayerOnly: true,
        minimumAlpha: 0.9,
        includeHidden: false,
        includeMinimized: true,
        includeInactiveSpaces: false,  // Active space only for CLI
        requireTitle: false,  // Allow windows without titles (will use app name fallback)
        requireProperSubrole: true,  // Require proper AX subrole
        bundleIdentifierWhitelist: nil,
        bundleIdentifierBlacklist: [],
        excludeSystemProcesses: true,
        applicationNameExcludeList: [],
        untitledWindowExcludeList: [],
        useAccessibilityAPI: true,
        includeSpaceInfo: true
    )
}
