import Foundation

/// Application metadata from NSWorkspace
public struct AppInfo: Sendable, Equatable, Identifiable {
    /// Process identifier
    public let processID: pid_t

    /// Bundle identifier (e.g., "com.apple.Safari")
    public let bundleIdentifier: String?

    /// Localized application name
    public let localizedName: String?

    /// Activation policy (0 = regular, 1 = accessory, 2 = prohibited)
    public let activationPolicy: Int

    public var id: pid_t { processID }

    public init(
        processID: pid_t,
        bundleIdentifier: String?,
        localizedName: String?,
        activationPolicy: Int
    ) {
        self.processID = processID
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
        self.activationPolicy = activationPolicy
    }
}

/// Protocol for workspace providers (abstracts NSWorkspace)
public protocol WorkspaceProviderProtocol: Sendable {
    /// Get list of running applications
    ///
    /// Queries NSWorkspace for currently running applications.
    /// Returns metadata for all apps regardless of activation policy.
    ///
    /// - Returns: Array of application metadata
    @MainActor
    func runningApplications() -> [AppInfo]
}
