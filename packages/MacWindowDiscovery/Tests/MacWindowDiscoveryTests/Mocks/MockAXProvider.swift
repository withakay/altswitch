import Foundation
import CoreGraphics
@testable import MacWindowDiscovery

/// Mock AX provider for testing
public final class MockAXProvider: AXWindowProviderProtocol, @unchecked Sendable {

    public var windowLookup: [CGWindowID: AXWindowInfo] = [:]
    public var callCount = 0

    public init() {}

    nonisolated public func buildWindowLookup(
        for pid: pid_t,
        bundleIdentifier: String
    ) -> [CGWindowID: AXWindowInfo] {
        callCount += 1
        return windowLookup
    }

    // MARK: - Test Helpers

    public func reset() {
        windowLookup = [:]
        callCount = 0
    }

    public func addMockWindowInfo(
        id: CGWindowID,
        isMinimized: Bool = false,
        isHidden: Bool = false,
        isFullscreen: Bool = false,
        isFocused: Bool = false,
        title: String? = "Test Window",
        subrole: String? = "AXStandardWindow"
    ) {
        windowLookup[id] = AXWindowInfo(
            isMinimized: isMinimized,
            isHidden: isHidden,
            isFullscreen: isFullscreen,
            isFocused: isFocused,
            title: title,
            role: "AXWindow",
            subrole: subrole
        )
    }
}
