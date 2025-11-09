import Foundation
import CoreGraphics
@testable import MacWindowDiscovery

/// Mock window provider for testing
public final class MockWindowProvider: WindowProviderProtocol, @unchecked Sendable {

    public var capturedWindows: [[String: Any]] = []
    public var shouldThrowError: Error?
    public var callCount = 0

    public init() {}

    nonisolated public func captureWindowList(
        option: CGWindowListOption = .optionOnScreenOnly
    ) throws -> [[String: Any]] {
        callCount += 1

        if let error = shouldThrowError {
            throw error
        }

        return capturedWindows
    }

    // MARK: - Test Helpers

    public func reset() {
        capturedWindows = []
        shouldThrowError = nil
        callCount = 0
    }

    public func addMockWindow(
        id: CGWindowID,
        pid: pid_t,
        title: String = "Test Window",
        bounds: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
    ) {
        let window: [String: Any] = [
            kCGWindowNumber as String: id,
            kCGWindowOwnerPID as String: pid,
            kCGWindowName as String: title,
            kCGWindowBounds as String: [
                "X": bounds.origin.x,
                "Y": bounds.origin.y,
                "Width": bounds.size.width,
                "Height": bounds.size.height
            ],
            kCGWindowLayer as String: 0,
            kCGWindowAlpha as String: 1.0,
            kCGWindowIsOnscreen as String: true
        ]

        capturedWindows.append(window)
    }
}
