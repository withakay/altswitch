import Foundation
import CoreGraphics
import ApplicationServices

/// Resolves process identity information for windows.
public struct WindowIdentityResolver {
    public init() {}

    /// Resolve the owning process ID for a given `CGWindowID` by consulting CoreGraphics window list.
    /// Returns `nil` if the window cannot be found.
    nonisolated public func resolveProcessID(for windowID: CGWindowID) -> pid_t? {
        guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for entry in list {
            if let wid = entry[kCGWindowNumber as String] as? CGWindowID, wid == windowID,
               let pid = entry[kCGWindowOwnerPID as String] as? pid_t {
                return pid
            }
        }
        return nil
    }
}

