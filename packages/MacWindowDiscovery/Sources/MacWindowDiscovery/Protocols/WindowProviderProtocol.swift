import Foundation
import CoreGraphics

/// Protocol for window list providers (abstracts CGWindowList)
public protocol WindowProviderProtocol: Sendable {
    /// Capture list of windows from the system
    ///
    /// Returns an array of dictionaries containing window metadata from CGWindowList.
    /// Each dictionary contains keys like kCGWindowNumber, kCGWindowBounds, etc.
    ///
    /// - Parameter option: Window list option (all, on-screen, etc.)
    /// - Returns: Array of window dictionaries
    /// - Throws: WindowDiscoveryError if capture fails
    nonisolated func captureWindowList(
        option: CGWindowListOption
    ) throws -> [[String: Any]]
}

/// Default implementation with standard option
extension WindowProviderProtocol {
    public func captureWindowList() throws -> [[String: Any]] {
        try captureWindowList(option: .optionOnScreenOnly)
    }
}
