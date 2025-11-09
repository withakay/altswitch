import Testing
import Foundation
import CoreGraphics
import AppKit
@testable import MacWindowDiscovery

@Suite("WindowEventMonitor Tests")
@MainActor
struct WindowEventMonitorTests {

    @Test("Starts and stops monitoring")
    func testStartStop() {
        let cache = WindowCache()
        let notificationCenter = NotificationCenter()
        let monitor = WindowEventMonitor(cache: cache, notificationCenter: notificationCenter)

        // Should not crash
        monitor.start()
        monitor.stop()
    }

    @Test("Invalidates cache on app launch")
    func testAppLaunch() async throws {
        let cache = WindowCache()
        let notificationCenter = NotificationCenter()
        let monitor = WindowEventMonitor(cache: cache, notificationCenter: notificationCenter)

        // Populate cache
        await cache.set(
            .bundleIdentifier("com.test.app", options: .default),
            windows: [makeTestWindow(id: 1)]
        )
        await cache.set(.allWindows(options: .default), windows: [makeTestWindow(id: 2)])

        monitor.start()

        // Post launch notification
        let app = MockRunningApplication(
            processIdentifier: 100,
            bundleIdentifier: "com.test.app"
        )
        notificationCenter.post(
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app]
        )

        // Wait for async invalidation
        try await Task.sleep(for: .milliseconds(50))

        // Cache should be invalidated
        let bundleResult = await cache.get(.bundleIdentifier("com.test.app", options: .default))
        let allResult = await cache.get(.allWindows(options: .default))

        #expect(bundleResult == nil)
        #expect(allResult == nil)

        monitor.stop()
    }

    @Test("Invalidates cache on app terminate")
    func testAppTerminate() async throws {
        let cache = WindowCache()
        let notificationCenter = NotificationCenter()
        let monitor = WindowEventMonitor(cache: cache, notificationCenter: notificationCenter)

        // Populate cache
        await cache.set(
            .bundleIdentifier("com.test.app", options: .default),
            windows: [makeTestWindow(id: 1)]
        )

        monitor.start()

        // Post terminate notification
        let app = MockRunningApplication(
            processIdentifier: 100,
            bundleIdentifier: "com.test.app"
        )
        notificationCenter.post(
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app]
        )

        // Wait for async invalidation
        try await Task.sleep(for: .milliseconds(50))

        // Cache should be invalidated
        let result = await cache.get(.bundleIdentifier("com.test.app", options: .default))
        #expect(result == nil)

        monitor.stop()
    }

    @Test("Invalidates cache on app hide")
    func testAppHide() async throws {
        let cache = WindowCache()
        let notificationCenter = NotificationCenter()
        let monitor = WindowEventMonitor(cache: cache, notificationCenter: notificationCenter)

        await cache.set(
            .bundleIdentifier("com.test.app", options: .default),
            windows: [makeTestWindow(id: 1)]
        )

        monitor.start()

        let app = MockRunningApplication(
            processIdentifier: 100,
            bundleIdentifier: "com.test.app"
        )
        notificationCenter.post(
            name: NSWorkspace.didHideApplicationNotification,
            object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app]
        )

        try await Task.sleep(for: .milliseconds(50))

        let result = await cache.get(.bundleIdentifier("com.test.app", options: .default))
        #expect(result == nil)

        monitor.stop()
    }

    @Test("Calls custom handlers on invalidation")
    func testCustomHandlers() async throws {
        let cache = WindowCache()
        let notificationCenter = NotificationCenter()
        let monitor = WindowEventMonitor(cache: cache, notificationCenter: notificationCenter)

        actor HandlerState {
            var called = false
            var event: InvalidationEvent?

            func setCalled(_ value: Bool) {
                called = value
            }

            func setEvent(_ event: InvalidationEvent) {
                self.event = event
            }
        }

        let state = HandlerState()

        monitor.addHandler { event in
            Task {
                await state.setCalled(true)
                await state.setEvent(event)
            }
        }

        monitor.start()

        let app = MockRunningApplication(
            processIdentifier: 100,
            bundleIdentifier: "com.test.app"
        )
        notificationCenter.post(
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            userInfo: [NSWorkspace.applicationUserInfoKey: app]
        )

        try await Task.sleep(for: .milliseconds(100))

        let called = await state.called
        let receivedEvent = await state.event

        #expect(called == true)
        #expect(receivedEvent?.type == .appLaunch)
        #expect(receivedEvent?.processID == 100)
        #expect(receivedEvent?.bundleIdentifier == "com.test.app")

        monitor.stop()
    }

    // MARK: - Helpers

    private func makeTestWindow(id: CGWindowID) -> WindowInfo {
        WindowInfo(
            id: id,
            title: "Test",
            bounds: .zero,
            alpha: 1.0,
            isOnScreen: true,
            layer: 0,
            processID: 100,
            bundleIdentifier: nil,
            applicationName: nil,
            isMinimized: false,
            isHidden: false,
            isFullscreen: false,
            isFocused: false,
            isMainWindow: false,
            isTabbed: false,
            spaceIDs: [],
            isOnAllSpaces: false,
            desktopNumber: nil,
            displayID: 1,
            role: nil,
            subrole: nil,
            capturedAt: Date()
        )
    }
}

// MARK: - Mock Running Application

private class MockRunningApplication: NSRunningApplication {
    private let _processIdentifier: pid_t
    private let _bundleIdentifier: String?

    init(processIdentifier: pid_t, bundleIdentifier: String?) {
        self._processIdentifier = processIdentifier
        self._bundleIdentifier = bundleIdentifier
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var processIdentifier: pid_t {
        _processIdentifier
    }

    override var bundleIdentifier: String? {
        _bundleIdentifier
    }
}
