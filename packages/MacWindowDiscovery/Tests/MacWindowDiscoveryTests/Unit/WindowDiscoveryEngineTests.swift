import Testing
import CoreGraphics
@testable import MacWindowDiscovery

@Suite("WindowDiscoveryEngine Tests")
struct WindowDiscoveryEngineTests {

    @Test("Initializes with default providers")
    func testDefaultInit() {
        let _ = WindowDiscoveryEngine()
        // Should not crash - test passes if init succeeds
    }

    @Test("Initializes with custom providers")
    @MainActor
    func testCustomInit() {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        let _ = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )
        // Should not crash - test passes if init succeeds
    }

    @Test("Discovers windows with mocks")
    @MainActor
    func testDiscoveryWithMocks() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        // Set up mock data
        cgProvider.addMockWindow(id: 1, pid: 100)
        cgProvider.addMockWindow(id: 2, pid: 100)

        workspaceProvider.addMockApp(
            pid: 100,
            bundleIdentifier: "com.test.app",
            localizedName: "Test App"
        )

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let windows = try await engine.discoverWindows()

        #expect(windows.count == 2)
        #expect(windows[0].processID == 100)
        #expect(windows[0].applicationName == "Test App")
    }

    @Test("Filters by process ID")
    @MainActor
    func testFilterByProcessID() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        // Add windows from multiple processes
        cgProvider.addMockWindow(id: 1, pid: 100)
        cgProvider.addMockWindow(id: 2, pid: 200)

        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.app1", localizedName: "App 1")
        workspaceProvider.addMockApp(pid: 200, bundleIdentifier: "com.app2", localizedName: "App 2")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let windows = try await engine.discoverWindows(forProcessID: 100)

        #expect(windows.count == 1)
        #expect(windows[0].processID == 100)
    }

    @Test("Filters by bundle identifier")
    @MainActor
    func testFilterByBundleID() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        cgProvider.addMockWindow(id: 1, pid: 100)
        cgProvider.addMockWindow(id: 2, pid: 200)

        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.wanted.app", localizedName: "Wanted")
        workspaceProvider.addMockApp(pid: 200, bundleIdentifier: "com.other.app", localizedName: "Other")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let windows = try await engine.discoverWindows(forBundleIdentifier: "com.wanted.app")

        #expect(windows.count == 1)
        #expect(windows[0].bundleIdentifier == "com.wanted.app")
    }

    @Test("Applies size filters")
    @MainActor
    func testSizeFilter() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        // Add small window
        cgProvider.addMockWindow(
            id: 1,
            pid: 100,
            bounds: CGRect(x: 0, y: 0, width: 50, height: 50)
        )

        // Add large window
        cgProvider.addMockWindow(
            id: 2,
            pid: 100,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600)
        )

        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.test", localizedName: "Test")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        var options = WindowDiscoveryOptions.default
        options.minimumSize = CGSize(width: 100, height: 100)

        let windows = try await engine.discoverWindows(options: options)

        // Only large window should pass
        #expect(windows.count == 1)
        #expect(windows[0].id == 2)
    }
}
