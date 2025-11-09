import Foundation
import AppKit

/// Concrete implementation of WorkspaceProviderProtocol using NSWorkspace
public struct NSWorkspaceProvider: WorkspaceProviderProtocol {

    public init() {}

    @MainActor
    public func runningApplications() -> [AppInfo] {
        NSWorkspace.shared.runningApplications.map { app in
            AppInfo(
                processID: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier,
                localizedName: app.localizedName,
                activationPolicy: app.activationPolicy.rawValue
            )
        }
    }
}
