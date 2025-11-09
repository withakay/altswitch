import Foundation
import CoreGraphics
import ApplicationServices

/// Dependencies used to resolve process and AX info for activation by window ID only.
public struct ActivationDependencies {
    public var pidResolver: (CGWindowID) -> pid_t?
    public var axResolver: @MainActor (CGWindowID) -> AXUIElement?

    public init(
        pidResolver: @escaping (CGWindowID) -> pid_t?,
        axResolver: @escaping @MainActor (CGWindowID) -> AXUIElement?
    ) {
        self.pidResolver = pidResolver
        self.axResolver = axResolver
    }
}

