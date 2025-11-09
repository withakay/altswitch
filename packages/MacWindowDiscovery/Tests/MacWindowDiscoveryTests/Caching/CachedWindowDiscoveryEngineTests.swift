import Testing
import Foundation
@testable import MacWindowDiscovery

@Suite("CachedWindowDiscoveryEngine Tests")
struct CachedWindowDiscoveryEngineTests {

    @Test("Uses cache on subsequent calls")
    @MainActor
    func testCaching() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        cgProvider.addMockWindow(id: 1, pid: 100)
        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.test", localizedName: "Test")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let cache = WindowCache(defaultTTL: 10.0)
        let cachedEngine = CachedWindowDiscoveryEngine(
            engine: engine,
            cache: cache,
            monitor: nil
        )

        // First call - should hit provider
        let windows1 = try await cachedEngine.discoverWindows()
        #expect(windows1.count == 1)
        #expect(cgProvider.callCount == 1)

        // Second call - should use cache
        let windows2 = try await cachedEngine.discoverWindows()
        #expect(windows2.count == 1)
        #expect(cgProvider.callCount == 1) // Not called again

        // Verify cache statistics
        let stats = await cachedEngine.cacheStatistics()
        #expect(stats.hits == 1)
        #expect(stats.misses == 1)
    }

    @Test("Respects TTL expiration")
    @MainActor
    func testTTLExpiration() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        cgProvider.addMockWindow(id: 1, pid: 100)
        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.test", localizedName: "Test")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let cache = WindowCache(defaultTTL: 0.1) // 100ms
        let cachedEngine = CachedWindowDiscoveryEngine(
            engine: engine,
            cache: cache,
            monitor: nil
        )

        // First call
        _ = try await cachedEngine.discoverWindows()
        #expect(cgProvider.callCount == 1)

        // Wait for expiration
        try await Task.sleep(for: .milliseconds(150))

        // Should call provider again
        _ = try await cachedEngine.discoverWindows()
        #expect(cgProvider.callCount == 2)
    }

    @Test("Caches by options")
    @MainActor
    func testCachingByOptions() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        cgProvider.addMockWindow(id: 1, pid: 100)
        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.test", localizedName: "Test")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let cache = WindowCache(defaultTTL: 10.0)
        let cachedEngine = CachedWindowDiscoveryEngine(
            engine: engine,
            cache: cache,
            monitor: nil
        )

        // Call with default options
        _ = try await cachedEngine.discoverWindows(options: .default)
        #expect(cgProvider.callCount == 1)

        // Call with different options - should not use cache
        _ = try await cachedEngine.discoverWindows(options: .fast)
        #expect(cgProvider.callCount == 2)

        // Call with default again - should use cache
        _ = try await cachedEngine.discoverWindows(options: .default)
        #expect(cgProvider.callCount == 2)
    }

    @Test("Caches per-process queries separately")
    @MainActor
    func testPerProcessCaching() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        cgProvider.addMockWindow(id: 1, pid: 100)
        cgProvider.addMockWindow(id: 2, pid: 200)
        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.test1", localizedName: "Test1")
        workspaceProvider.addMockApp(pid: 200, bundleIdentifier: "com.test2", localizedName: "Test2")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let cache = WindowCache(defaultTTL: 10.0)
        let cachedEngine = CachedWindowDiscoveryEngine(
            engine: engine,
            cache: cache,
            monitor: nil
        )

        // Query for process 100
        let windows1 = try await cachedEngine.discoverWindows(forProcessID: 100)
        #expect(windows1.count == 1)

        // Query for process 100 again - should use cache
        let windows2 = try await cachedEngine.discoverWindows(forProcessID: 100)
        #expect(windows2.count == 1)

        // Query for process 200 - different cache entry
        let windows3 = try await cachedEngine.discoverWindows(forProcessID: 200)
        #expect(windows3.count == 1)

        let stats = await cachedEngine.cacheStatistics()
        #expect(stats.hits == 1)
        #expect(stats.misses == 2)
    }

    @Test("Manual cache invalidation works")
    @MainActor
    func testManualInvalidation() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        cgProvider.addMockWindow(id: 1, pid: 100)
        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.test", localizedName: "Test")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let cache = WindowCache(defaultTTL: 10.0)
        let cachedEngine = CachedWindowDiscoveryEngine(
            engine: engine,
            cache: cache,
            monitor: nil
        )

        // First call
        _ = try await cachedEngine.discoverWindows()
        #expect(cgProvider.callCount == 1)

        // Invalidate cache
        await cachedEngine.clearCache()

        // Should call provider again
        _ = try await cachedEngine.discoverWindows()
        #expect(cgProvider.callCount == 2)
    }

    @Test("Invalidates cache for specific process")
    @MainActor
    func testProcessInvalidation() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        cgProvider.addMockWindow(id: 1, pid: 100)
        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.test", localizedName: "Test")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let cache = WindowCache(defaultTTL: 10.0)
        let cachedEngine = CachedWindowDiscoveryEngine(
            engine: engine,
            cache: cache,
            monitor: nil
        )

        // Cache a result
        _ = try await cachedEngine.discoverWindows(forProcessID: 100)
        #expect(cgProvider.callCount == 1)

        // Invalidate this process
        await cachedEngine.invalidateCache(forProcessID: 100)

        // Should call provider again
        _ = try await cachedEngine.discoverWindows(forProcessID: 100)
        #expect(cgProvider.callCount == 2)
    }

    @Test("Prune removes expired entries")
    @MainActor
    func testPrune() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        cgProvider.addMockWindow(id: 1, pid: 100)
        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.test", localizedName: "Test")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let cache = WindowCache(defaultTTL: 0.1) // 100ms
        let cachedEngine = CachedWindowDiscoveryEngine(
            engine: engine,
            cache: cache,
            monitor: nil
        )

        // Create a cached entry
        _ = try await cachedEngine.discoverWindows()

        var stats = await cachedEngine.cacheStatistics()
        #expect(stats.entryCount == 1)

        // Wait for expiration
        try await Task.sleep(for: .milliseconds(150))

        // Prune
        await cachedEngine.pruneCache()

        stats = await cachedEngine.cacheStatistics()
        #expect(stats.entryCount == 0)
    }

    @Test("Statistics reset works")
    @MainActor
    func testStatisticsReset() async throws {
        let cgProvider = MockWindowProvider()
        let axProvider = MockAXProvider()
        let workspaceProvider = MockWorkspaceProvider()

        cgProvider.addMockWindow(id: 1, pid: 100)
        workspaceProvider.addMockApp(pid: 100, bundleIdentifier: "com.test", localizedName: "Test")

        let engine = WindowDiscoveryEngine(
            cgProvider: cgProvider,
            axProvider: axProvider,
            workspaceProvider: workspaceProvider
        )

        let cache = WindowCache(defaultTTL: 10.0)
        let cachedEngine = CachedWindowDiscoveryEngine(
            engine: engine,
            cache: cache,
            monitor: nil
        )

        // Generate some hits/misses
        _ = try await cachedEngine.discoverWindows()
        _ = try await cachedEngine.discoverWindows()

        var stats = await cachedEngine.cacheStatistics()
        #expect(stats.hits > 0)

        // Reset
        await cachedEngine.resetStatistics()

        stats = await cachedEngine.cacheStatistics()
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)
    }
}
