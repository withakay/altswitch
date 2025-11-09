import Testing
import Foundation
import CoreGraphics
@testable import MacWindowDiscovery

@Suite("WindowDiscoveryEngine Integration Tests")
struct WindowDiscoveryEngineIntegrationTests {

    @Test("Discovers real system windows")
    func testRealDiscovery() async throws {
        let engine = WindowDiscoveryEngine()
        let windows = try await engine.discoverWindows()

        // Should find at least some windows
        #expect(windows.count > 0)

        // Each window should have valid data
        for window in windows {
            #expect(window.id > 0)
            #expect(window.processID > 0)
            #expect(window.bounds.width > 0)
            #expect(window.bounds.height > 0)
        }
    }

    @Test("Performance meets requirements")
    func testPerformance() async throws {
        let engine = WindowDiscoveryEngine()

        let start = Date()
        let windows = try await engine.discoverWindows()
        let elapsed = Date().timeIntervalSince(start)

        print("Discovered \(windows.count) windows in \(elapsed * 1000)ms")

        // Should complete in < 200ms for typical workload (being generous for test runners)
        #expect(elapsed < 0.2)
    }

    @Test("Fast mode is faster than default")
    func testFastMode() async throws {
        let engine = WindowDiscoveryEngine()

        // Default mode (with AX)
        let defaultStart = Date()
        _ = try await engine.discoverWindows(options: .default)
        let defaultTime = Date().timeIntervalSince(defaultStart)

        // Fast mode (no AX)
        let fastStart = Date()
        _ = try await engine.discoverWindows(options: .fast)
        let fastTime = Date().timeIntervalSince(fastStart)

        print("Default: \(defaultTime * 1000)ms, Fast: \(fastTime * 1000)ms")

        // Fast mode should be faster or equal
        #expect(fastTime <= defaultTime + 0.05) // Allow 50ms tolerance
    }

    @Test("Works without AX permissions")
    func testNoAXPermissions() async throws {
        let engine = WindowDiscoveryEngine()

        // Fast mode doesn't require AX
        let windows = try await engine.discoverWindows(options: .fast)

        #expect(windows.count > 0)
    }
}
