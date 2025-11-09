import Foundation
import CoreGraphics

/// Builds WindowInfo objects from various data sources
struct WindowInfoBuilder {

    private let titleCache: WindowTitleCache?

    init(titleCache: WindowTitleCache? = nil) {
        self.titleCache = titleCache
    }

    /// Build a complete WindowInfo from multiple sources
    ///
    /// Combines CG, AX, Workspace, and Spaces data into a single WindowInfo.
    ///
    /// - Parameters:
    ///   - cgData: Window data from CGWindowList
    ///   - axInfo: Optional AX enrichment data
    ///   - appInfo: Optional application metadata
    ///   - spaces: Space IDs for this window
    /// - Returns: Complete WindowInfo object
    func buildWindowInfo(
        from cgData: [String: Any],
        axInfo: AXWindowInfo?,
        appInfo: AppInfo?,
        spaces: [Int]
    ) async -> WindowInfo {
        // Extract required fields from CG data
        let id = cgData[kCGWindowNumber as String] as? CGWindowID ?? 0
        let processID = cgData[kCGWindowOwnerPID as String] as? pid_t ?? 0
        let bounds = extractBounds(from: cgData)
        let alpha = cgData[kCGWindowAlpha as String] as? Double ?? 1.0
        let layer = cgData[kCGWindowLayer as String] as? Int ?? 0
        let isOnScreen = cgData[kCGWindowIsOnscreen as String] as? Bool ?? true

        // Extract CG title from CGWindowList data
        let cgTitle = cgData[kCGWindowName as String] as? String ?? ""

        // Title priority:
        // 1. AX title (most accurate, but only for active space windows) - cache it!
        // 2. CG title (from CGWindowList - works for Finder and many apps)
        // 3. Cached title (from when window was on active space)
        // 4. Empty string
        let title: String
        if let axTitle = axInfo?.title, !axTitle.isEmpty {
            // We have an AX title - cache it for future use
            title = axTitle
            await titleCache?.set(windowID: id, title: axTitle)
        } else if !cgTitle.isEmpty {
            // Use CG title from CGWindowList (works for Finder, etc.)
            title = cgTitle
            // Also cache the CG title for consistency
            await titleCache?.set(windowID: id, title: cgTitle)
        } else if let cachedTitle = await titleCache?.get(windowID: id), !cachedTitle.isEmpty {
            // No AX or CG title, but we have a cached title from before
            title = cachedTitle
        } else {
            title = ""
        }

        // Application metadata
        let bundleIdentifier = appInfo?.bundleIdentifier
        let applicationName = appInfo?.localizedName

        // Window state from AX
        let isMinimized = axInfo?.isMinimized ?? false
        let isHidden = axInfo?.isHidden ?? false
        let isFullscreen = axInfo?.isFullscreen ?? false
        let isFocused = axInfo?.isFocused ?? false
        let isMainWindow = axInfo?.isMainWindow ?? false
        let isTabbed = axInfo?.isTabbed ?? false

        // Accessibility role/subrole
        let role = axInfo?.role
        let subrole = axInfo?.subrole

        // Spaces information
        let spaceIDs = spaces
        let isOnAllSpaces = spaces.isEmpty ? false : spaces.count > 1

        // Display information
        let displayID = SpacesAPI.getDisplayForWindow(bounds)

        // Calculate user-friendly desktop number
        let desktopNumber = calculateDesktopNumber(
            spaceIDs: spaceIDs,
            displayID: displayID
        )

        return WindowInfo(
            id: id,
            title: title,
            bounds: bounds,
            alpha: alpha,
            isOnScreen: isOnScreen,
            layer: layer,
            processID: processID,
            bundleIdentifier: bundleIdentifier,
            applicationName: applicationName,
            isMinimized: isMinimized,
            isHidden: isHidden,
            isFullscreen: isFullscreen,
            isFocused: isFocused,
            isMainWindow: isMainWindow,
            isTabbed: isTabbed,
            spaceIDs: spaceIDs,
            isOnAllSpaces: isOnAllSpaces,
            desktopNumber: desktopNumber,
            displayID: displayID,
            role: role,
            subrole: subrole,
            capturedAt: Date()
        )
    }

    // MARK: - Private Helpers

    private func extractBounds(from cgData: [String: Any]) -> CGRect {
        guard let boundsDict = cgData[kCGWindowBounds as String] as? [String: CGFloat] else {
            return .zero
        }

        let x = boundsDict["X"] ?? 0
        let y = boundsDict["Y"] ?? 0
        let width = boundsDict["Width"] ?? 0
        let height = boundsDict["Height"] ?? 0

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Calculate user-friendly desktop number for a window
    ///
    /// The desktop number is the 1-indexed position of the space in Mission Control's
    /// left-to-right ordering for the window's display. Each display has its own
    /// Desktop 1, 2, 3, etc.
    ///
    /// - Parameters:
    ///   - spaceIDs: Space IDs where the window appears
    ///   - displayID: The display where the window is located
    /// - Returns: Desktop number (1-indexed) or nil if it cannot be determined
    private func calculateDesktopNumber(
        spaceIDs: [Int],
        displayID: CGDirectDisplayID
    ) -> Int? {
        // Need at least one space ID to determine desktop number
        guard let firstSpaceID = spaceIDs.first else {
            return nil
        }

        // Get all display spaces information
        let allDisplaySpaces = SpacesAPI.getAllDisplaySpaces()

        // Find the display that matches our window's display
        guard let displayInfo = allDisplaySpaces.first(where: { $0.displayID == displayID }) else {
            return nil
        }

        // Find the position of the space ID in the ordered list
        guard let index = displayInfo.allSpaceIDs.firstIndex(of: firstSpaceID) else {
            return nil
        }

        // Convert 0-indexed to 1-indexed (Desktop 1, Desktop 2, etc.)
        return index + 1
    }
}
