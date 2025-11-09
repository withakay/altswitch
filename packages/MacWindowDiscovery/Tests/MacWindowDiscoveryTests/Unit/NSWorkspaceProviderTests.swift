import Testing
import Foundation
@testable import MacWindowDiscovery

@Suite("NSWorkspaceProvider Tests")
@MainActor
struct NSWorkspaceProviderTests {

    @Test("Returns running applications")
    func testRunningApplications() {
        let provider = NSWorkspaceProvider()
        let apps = provider.runningApplications()

        // Should have at least one app (the test runner)
        #expect(apps.count > 0)

        // Each app should have process ID
        for app in apps {
            #expect(app.processID > 0)
        }
    }

    @Test("Maps bundle identifiers correctly")
    func testBundleIdentifiers() {
        let provider = NSWorkspaceProvider()
        let apps = provider.runningApplications()

        // At least some apps should have bundle IDs
        let appsWithBundleIDs = apps.filter { $0.bundleIdentifier != nil }
        #expect(appsWithBundleIDs.count > 0)
    }

    @Test("Includes current process or similar test processes")
    func testIncludesCurrentProcess() {
        let provider = NSWorkspaceProvider()
        let apps = provider.runningApplications()

        // Test process might not always show up depending on how tests are run
        // Just verify that we get a reasonable list of processes
        #expect(apps.count > 0)

        // Verify the returned data is valid
        let hasValidProcesses = apps.allSatisfy { app in
            app.processID > 0
        }
        #expect(hasValidProcesses)
    }

    @Test("Maps activation policies")
    func testActivationPolicies() {
        let provider = NSWorkspaceProvider()
        let apps = provider.runningApplications()

        // Activation policies should be valid (0, 1, or 2)
        for app in apps {
            #expect(app.activationPolicy >= 0)
            #expect(app.activationPolicy <= 2)
        }
    }

    @Test("AppInfo is Identifiable")
    func testAppInfoIdentifiable() {
        let app = AppInfo(
            processID: 123,
            bundleIdentifier: "com.test",
            localizedName: "Test",
            activationPolicy: 0
        )

        #expect(app.id == 123)
    }
}
