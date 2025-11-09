import Foundation
import CoreGraphics

// Import RTLD_DEFAULT constant
#if canImport(Darwin)
import Darwin
#endif

/// Information about a display and its spaces
public struct DisplaySpaceInfo: Sendable, Codable {
    /// Display identifier
    public let displayID: CGDirectDisplayID

    /// Display UUID
    public let displayUUID: String?

    /// Current active space on this display
    public let currentSpaceID: Int

    /// All spaces available on this display
    public let allSpaceIDs: [Int]

    /// Display bounds
    public let bounds: CGRect

    /// Whether this is the main display
    public let isMain: Bool

    public init(
        displayID: CGDirectDisplayID,
        displayUUID: String?,
        currentSpaceID: Int,
        allSpaceIDs: [Int],
        bounds: CGRect,
        isMain: Bool
    ) {
        self.displayID = displayID
        self.displayUUID = displayUUID
        self.currentSpaceID = currentSpaceID
        self.allSpaceIDs = allSpaceIDs
        self.bounds = bounds
        self.isMain = isMain
    }
}

/// Platform-specific Spaces API with automatic fallback
public enum SpacesAPI {

    // MARK: - Availability Checking

    /// Check if private Spaces API is available on this system
    public static func isAvailable() -> Bool {
        // Check macOS version
        guard #available(macOS 13, *) else {
            return false
        }

        // Check if symbols are available at runtime
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        return dlsym(rtldDefault, "CGSCopyManagedDisplaySpaces") != nil &&
               dlsym(rtldDefault, "CGSMainConnectionID") != nil &&
               dlsym(rtldDefault, "CGSCopySpacesForWindows") != nil
    }

    // MARK: - Public API

    /// Get Space IDs for a window (with fallback)
    ///
    /// Returns:
    /// - On success: Array of Space IDs where window appears
    /// - On fallback: Empty array (unable to determine)
    public static func getWindowSpaces(_ windowID: CGWindowID) -> [Int] {
        guard isAvailable() else {
            return []
        }

        do {
            return try getWindowSpaces_Private(windowID)
        } catch {
            print("⚠️  Spaces API failed for window \(windowID): \(error)")
            return []
        }
    }

    /// Get the currently active Space ID (with fallback)
    ///
    /// Returns:
    /// - On success: Active Space ID (first active space found)
    /// - On fallback: 0 (represents "unknown")
    public static func activeSpaceID() -> Int {
        guard isAvailable() else {
            return 0
        }

        do {
            return try activeSpaceID_Private()
        } catch {
            print("⚠️  Unable to determine active Space: \(error)")
            return 0
        }
    }

    /// Get all currently active Space IDs across all displays (with fallback)
    ///
    /// Returns:
    /// - On success: Array of active Space IDs (one per display)
    /// - On fallback: Empty array
    public static func activeSpaceIDs() -> [Int] {
        guard isAvailable() else {
            return []
        }

        do {
            return try activeSpaceIDs_Private()
        } catch {
            print("⚠️  Unable to determine active Spaces: \(error)")
            return []
        }
    }

    /// Get comprehensive display and space information for all displays
    ///
    /// Returns:
    /// - On success: Array of DisplaySpaceInfo for each display
    /// - On fallback: Empty array
    public static func getAllDisplaySpaces() -> [DisplaySpaceInfo] {
        guard isAvailable() else {
            return []
        }

        do {
            return try getAllDisplaySpaces_Private()
        } catch {
            print("⚠️  Unable to get display spaces: \(error)")
            return []
        }
    }

    /// Get the display ID that a window is primarily on
    ///
    /// Returns the display ID where the window's center point is located
    public static func getDisplayForWindow(_ windowBounds: CGRect) -> CGDirectDisplayID {
        let centerPoint = CGPoint(
            x: windowBounds.midX,
            y: windowBounds.midY
        )

        var displayID: CGDirectDisplayID = 0
        var displayCount: UInt32 = 0

        // Get the display at the center point of the window
        CGGetDisplaysWithPoint(centerPoint, 1, &displayID, &displayCount)

        return displayID
    }

    // MARK: - Private API Declarations

    @_silgen_name("CGSCopyManagedDisplaySpaces")
    private static func CGSCopyManagedDisplaySpaces(
        _ connection: Int
    ) -> CFArray

    @_silgen_name("CGSMainConnectionID")
    private static func CGSMainConnectionID() -> Int

    @_silgen_name("CGSCopySpacesForWindows")
    private static func CGSCopySpacesForWindows(
        _ connection: Int,
        _ selector: Int,
        _ windowIDs: CFArray
    ) -> CFArray

    // MARK: - Private Implementation

    private static func getWindowSpaces_Private(_ windowID: CGWindowID) throws -> [Int] {
        let connection = CGSMainConnectionID()

        // Use CGSCopySpacesForWindows with selector 7 to get space IDs for this window
        let windowIDs = [windowID] as CFArray
        let spaces = CGSCopySpacesForWindows(connection, 7, windowIDs) as? [Int]

        return spaces ?? []
    }

    private static func activeSpaceID_Private() throws -> Int {
        let connection = CGSMainConnectionID()
        let displaySpaces = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]]

        guard let displaySpaces = displaySpaces else {
            throw WindowDiscoveryError.spacesAPIUnavailable
        }

        // Find the first active space
        for display in displaySpaces {
            guard let currentSpace = display["Current Space"] as? [String: Any],
                  let spaceID = currentSpace["id64"] as? Int else {
                continue
            }

            return spaceID
        }

        return 0
    }

    private static func activeSpaceIDs_Private() throws -> [Int] {
        let connection = CGSMainConnectionID()
        let displaySpaces = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]]

        guard let displaySpaces = displaySpaces else {
            throw WindowDiscoveryError.spacesAPIUnavailable
        }

        var activeSpaces: [Int] = []

        // Collect active space from each display
        for display in displaySpaces {
            guard let currentSpace = display["Current Space"] as? [String: Any],
                  let spaceID = currentSpace["id64"] as? Int else {
                continue
            }

            activeSpaces.append(spaceID)
        }

        return activeSpaces
    }

    private static func getAllDisplaySpaces_Private() throws -> [DisplaySpaceInfo] {
        let connection = CGSMainConnectionID()
        let displaySpaces = CGSCopyManagedDisplaySpaces(connection) as? [[String: Any]]

        guard let displaySpaces = displaySpaces else {
            throw WindowDiscoveryError.spacesAPIUnavailable
        }

        var result: [DisplaySpaceInfo] = []

        for display in displaySpaces {
            // Get display ID
            guard let displayID = display["Display Identifier"] as? CGDirectDisplayID else {
                continue
            }

            // Get display UUID
            let displayUUID = display["Display UUID"] as? String

            // Get current space
            guard let currentSpace = display["Current Space"] as? [String: Any],
                  let currentSpaceID = currentSpace["id64"] as? Int else {
                continue
            }

            // Get all spaces for this display
            var allSpaceIDs: [Int] = []
            if let spaces = display["Spaces"] as? [[String: Any]] {
                for space in spaces {
                    if let spaceID = space["id64"] as? Int {
                        allSpaceIDs.append(spaceID)
                    }
                }
            }

            // Get display bounds
            let bounds = CGDisplayBounds(displayID)

            // Check if main display
            let isMain = CGDisplayIsMain(displayID) != 0

            let info = DisplaySpaceInfo(
                displayID: displayID,
                displayUUID: displayUUID,
                currentSpaceID: currentSpaceID,
                allSpaceIDs: allSpaceIDs,
                bounds: bounds,
                isMain: isMain
            )

            result.append(info)
        }

        return result
    }
}
