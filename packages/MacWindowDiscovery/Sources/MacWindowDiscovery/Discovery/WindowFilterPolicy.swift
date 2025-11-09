import Foundation
import CoreGraphics

/// Applies filtering policy to windows based on options
struct WindowFilterPolicy {

    private let options: WindowDiscoveryOptions

    init(options: WindowDiscoveryOptions) {
        self.options = options
    }

    /// Determine if window should be included based on options
    ///
    /// - Parameters:
    ///   - windowData: CGWindowList dictionary
    ///   - axInfo: Optional AX window information
    ///   - appInfo: Optional application information
    ///   - spaceIDs: Space IDs this window belongs to
    /// - Returns: true if window should be included
    func shouldInclude(
        _ windowData: [String: Any],
        axInfo: AXWindowInfo?,
        appInfo: AppInfo?,
        spaceIDs: [Int] = []
    ) -> Bool {
        // Extract window properties
        guard let bounds = extractBounds(from: windowData) else {
            return false
        }

        let alpha = windowData[kCGWindowAlpha as String] as? Double ?? 1.0
        let layer = windowData[kCGWindowLayer as String] as? Int ?? 0

        // Apply size filter
        if bounds.width < options.minimumSize.width ||
           bounds.height < options.minimumSize.height {
            return false
        }

        // Apply alpha filter
        if alpha < options.minimumAlpha {
            return false
        }

        // Apply layer filter
        if options.normalLayerOnly && layer != 0 {
            return false
        }

        // Apply hidden filter
        if let axInfo = axInfo, !options.includeHidden && axInfo.isHidden {
            return false
        }

        // Apply minimized filter
        if let axInfo = axInfo, !options.includeMinimized && axInfo.isMinimized {
            return false
        }

        // Apply bundle identifier filters
        if let appInfo = appInfo, let bundleID = appInfo.bundleIdentifier {
            // Check whitelist (if present, only include whitelisted)
            if let whitelist = options.bundleIdentifierWhitelist {
                if !whitelist.contains(bundleID) {
                    return false
                }
            }

            // Check blacklist
            if options.bundleIdentifierBlacklist.contains(bundleID) {
                return false
            }

            // Check system processes
            if options.excludeSystemProcesses && isSystemProcess(bundleID) {
                return false
            }
        }

        // Apply space filter
        if !options.includeInactiveSpaces {
            let activeSpaceIDs = SpacesAPI.activeSpaceIDs()
            // If we have space info and active spaces, filter to active spaces only
            if !activeSpaceIDs.isEmpty && !spaceIDs.isEmpty {
                // Check if window is on any of the active spaces
                let isOnActiveSpace = spaceIDs.contains(where: { activeSpaceIDs.contains($0) })
                if !isOnActiveSpace {
                    return false
                }
            }
        }

        // Apply title requirement filter
        if options.requireTitle {
            // Check if window has a title from AX
            let hasTitle = axInfo?.title != nil && !axInfo!.title!.isEmpty
            if !hasTitle {
                return false
            }
        }

        // Apply subrole requirement filter
        if options.requireProperSubrole {
            // Check if window has proper AX subrole
            let validSubroles = ["AXStandardWindow", "AXDialog"]
            let hasProperSubrole = axInfo?.subrole != nil && validSubroles.contains(axInfo!.subrole!)

            // Allow windows with proper subrole OR windows on a real space (even without AX)
            // This handles windows on inactive spaces that don't have AX metadata
            let isOnRealSpace = !spaceIDs.isEmpty

            if !hasProperSubrole && !isOnRealSpace {
                // Reject windows without proper subrole AND not on any space (fake windows)
                return false
            }

            // For windows on real spaces without AX metadata (inactive space windows),
            // require larger minimum size to filter out UI elements (tab bars, toolbars, palettes, etc.)
            if !hasProperSubrole && isOnRealSpace {
                // Require minimum 800x500 for windows without AX metadata
                // This filters out tool palettes, floating panels, settings windows, download bars, etc.
                if bounds.width < 800 || bounds.height < 500 {
                    return false
                }
            }
        }

        return true
    }

    // MARK: - Private Helpers

    private func extractBounds(from windowData: [String: Any]) -> CGRect? {
        guard let boundsDict = windowData[kCGWindowBounds as String] as? [String: CGFloat] else {
            return nil
        }

        let x = boundsDict["X"] ?? 0
        let y = boundsDict["Y"] ?? 0
        let width = boundsDict["Width"] ?? 0
        let height = boundsDict["Height"] ?? 0

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func isSystemProcess(_ bundleIdentifier: String) -> Bool {
        let systemPrefixes = [
            "com.apple.controlcenter",
            "com.apple.systemuiserver",
            "com.apple.dock",
            "com.apple.notificationcenterui",
            "com.apple.WindowManager",
            "com.apple.loginwindow",
            "com.apple.AuthenticationServices",     // AutoFill panels
            "com.apple.AutoFillPanelService",       // AutoFill service
            "com.apple.SafariPlatformSupport",      // Safari AutoFill helper
            "com.apple.LocalAuthentication",        // LocalAuthenticationRemoteService
            "com.apple.UserNotificationCenter",     // UserNotificationCenter
            "com.apple.appkit.xpc",                 // Open and Save Panel Service
            "com.apple.Spotlight"                   // Spotlight window
        ]

        // Known menubar apps (these typically show only settings/preferences windows)
        let menubarApps = [
            "com.jordanbaird.Ice",                  // Ice menubar manager
            "com.browserino.Browserino"             // Browserino browser switcher
        ]

        return systemPrefixes.contains { bundleIdentifier.hasPrefix($0) } ||
               menubarApps.contains(bundleIdentifier)
    }
}
