import Foundation
import CoreGraphics

/// Concrete implementation of WindowProviderProtocol using CGWindowList
public struct CGWindowProvider: WindowProviderProtocol {

    public init() {}

    nonisolated public func captureWindowList(
        option: CGWindowListOption = .optionOnScreenOnly
    ) throws -> [[String: Any]] {
        // Call CGWindowListCopyWindowInfo
        guard let windowList = CGWindowListCopyWindowInfo(
            option,
            kCGNullWindowID
        ) as? [[String: Any]] else {
            throw WindowDiscoveryError.cgWindowListFailed(underlying: nil)
        }

        // Filter out windows without required fields
        let validWindows = windowList.filter { dict in
            // Must have window number
            guard dict[kCGWindowNumber as String] != nil else {
                return false
            }

            // Must have owner PID
            guard dict[kCGWindowOwnerPID as String] != nil else {
                return false
            }

            return true
        }

        return validWindows
    }
}

// MARK: - Helper Extensions

private extension Dictionary where Key == String, Value == Any {
    /// Safely get window number
    var windowNumber: CGWindowID? {
        self[kCGWindowNumber as String] as? CGWindowID
    }

    /// Safely get owner PID
    var ownerPID: pid_t? {
        self[kCGWindowOwnerPID as String] as? pid_t
    }
}
