import Foundation
@testable import MacWindowDiscovery

/// Mock workspace provider for testing
@MainActor
public final class MockWorkspaceProvider: WorkspaceProviderProtocol {

    public var apps: [AppInfo] = []
    public var callCount = 0

    public init() {}

    public func runningApplications() -> [AppInfo] {
        callCount += 1
        return apps
    }

    // MARK: - Test Helpers

    public func reset() {
        apps = []
        callCount = 0
    }

    public func addMockApp(
        pid: pid_t,
        bundleIdentifier: String,
        localizedName: String,
        activationPolicy: Int = 0
    ) {
        apps.append(AppInfo(
            processID: pid,
            bundleIdentifier: bundleIdentifier,
            localizedName: localizedName,
            activationPolicy: activationPolicy
        ))
    }
}
