import Foundation
import CoreGraphics

/// Validates window data from CGWindowList
struct WindowValidator {

    /// Check if window data is valid and should be processed
    ///
    /// Validates required fields and value ranges.
    ///
    /// - Parameter windowData: Dictionary from CGWindowList
    /// - Returns: true if window is valid
    func isValid(_ windowData: [String: Any]) -> Bool {
        // Must have window number
        guard let windowID = windowData[kCGWindowNumber as String] as? CGWindowID else {
            return false
        }

        // Must be positive
        guard windowID > 0 else {
            return false
        }

        // Must have owner PID
        guard let pid = windowData[kCGWindowOwnerPID as String] as? pid_t else {
            return false
        }

        // Must be positive
        guard pid > 0 else {
            return false
        }

        // Must have bounds
        guard let boundsDict = windowData[kCGWindowBounds as String] as? [String: CGFloat] else {
            return false
        }

        // Extract dimensions
        let width = boundsDict["Width"] ?? 0
        let height = boundsDict["Height"] ?? 0

        // Must have non-zero dimensions
        guard width > 0 && height > 0 else {
            return false
        }

        // Validate alpha if present
        if let alpha = windowData[kCGWindowAlpha as String] as? Double {
            guard alpha >= 0.0 && alpha <= 1.0 else {
                return false
            }
        }

        // Validate layer if present
        if let layer = windowData[kCGWindowLayer as String] as? Int {
            // Reject unreasonable layer values
            guard layer >= -1000 && layer <= 1000 else {
                return false
            }
        }

        return true
    }
}
