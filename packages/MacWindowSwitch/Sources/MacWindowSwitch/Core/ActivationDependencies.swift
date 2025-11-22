import ApplicationServices
import CoreGraphics
import Foundation

/// Dependencies used to resolve process and AX info for activation by window ID only.
public struct ActivationDependencies: Sendable {
    public var pidResolver: @Sendable (CGWindowID) -> pid_t?
    public var axResolver: @Sendable @MainActor (CGWindowID) -> AXUIElement?

    public init(
        pidResolver: @escaping @Sendable (CGWindowID) -> pid_t?,
        axResolver: @escaping @Sendable @MainActor (CGWindowID) -> AXUIElement?
    ) {
        self.pidResolver = pidResolver
        self.axResolver = axResolver
    }
}
