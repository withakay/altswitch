import Testing
import Foundation
import CoreGraphics
@testable import MacWindowDiscovery

@Suite("WindowCache Tests")
struct WindowCacheTests {

    @Test("Stores and retrieves cached windows")
    func testBasicCaching() async {
        let cache = WindowCache(defaultTTL: 10.0)
        let key = CacheKey.allWindows(options: .default)
        let windows = [
            makeTestWindow(id: 1),
            makeTestWindow(id: 2)
        ]

        await cache.set(key, windows: windows)
        let retrieved = await cache.get(key)

        #expect(retrieved?.count == 2)
        #expect(retrieved?[0].id == 1)
        #expect(retrieved?[1].id == 2)
    }

    @Test("Returns nil for cache miss")
    func testCacheMiss() async {
        let cache = WindowCache()
        let key = CacheKey.allWindows(options: .default)

        let result = await cache.get(key)
        #expect(result == nil)
    }

    @Test("Expires entries after TTL")
    func testTTLExpiration() async throws {
        let cache = WindowCache(defaultTTL: 0.1) // 100ms TTL
        let key = CacheKey.allWindows(options: .default)
        let windows = [makeTestWindow(id: 1)]

        await cache.set(key, windows: windows)

        // Should be available immediately
        let immediate = await cache.get(key)
        #expect(immediate != nil)

        // Wait for expiration
        try await Task.sleep(for: .milliseconds(150))

        // Should be expired
        let expired = await cache.get(key)
        #expect(expired == nil)
    }

    @Test("Custom TTL overrides default")
    func testCustomTTL() async throws {
        let cache = WindowCache(defaultTTL: 10.0) // Long default
        let key = CacheKey.allWindows(options: .default)
        let windows = [makeTestWindow(id: 1)]

        // Set with short custom TTL
        await cache.set(key, windows: windows, ttl: 0.1)

        // Should be available immediately
        let immediate = await cache.get(key)
        #expect(immediate != nil)

        // Wait for custom TTL expiration
        try await Task.sleep(for: .milliseconds(150))

        // Should be expired
        let expired = await cache.get(key)
        #expect(expired == nil)
    }

    @Test("Invalidates specific key")
    func testInvalidateKey() async {
        let cache = WindowCache()
        let key1 = CacheKey.allWindows(options: .default)
        let key2 = CacheKey.processID(100, options: .default)

        await cache.set(key1, windows: [makeTestWindow(id: 1)])
        await cache.set(key2, windows: [makeTestWindow(id: 2)])

        await cache.invalidate(key1)

        #expect(await cache.get(key1) == nil)
        #expect(await cache.get(key2) != nil)
    }

    @Test("Invalidates all entries for process")
    func testInvalidateProcess() async {
        let cache = WindowCache()

        await cache.set(.processID(100, options: .default), windows: [makeTestWindow(id: 1)])
        await cache.set(.processID(200, options: .default), windows: [makeTestWindow(id: 2)])
        await cache.set(.allWindows(options: .default), windows: [makeTestWindow(id: 3)])

        await cache.invalidateProcess(100)

        // Process 100 should be cleared
        #expect(await cache.get(.processID(100, options: .default)) == nil)

        // Process 200 should remain (but won't because allWindows invalidates all)
        // All windows should be cleared (since it includes process 100)
        #expect(await cache.get(.allWindows(options: .default)) == nil)
    }

    @Test("Invalidates all entries for bundle identifier")
    func testInvalidateBundleIdentifier() async {
        let cache = WindowCache()

        await cache.set(
            .bundleIdentifier("com.test.app1", options: .default),
            windows: [makeTestWindow(id: 1)]
        )
        await cache.set(
            .bundleIdentifier("com.test.app2", options: .default),
            windows: [makeTestWindow(id: 2)]
        )
        await cache.set(.allWindows(options: .default), windows: [makeTestWindow(id: 3)])

        await cache.invalidateBundleIdentifier("com.test.app1")

        // App1 should be cleared
        #expect(await cache.get(.bundleIdentifier("com.test.app1", options: .default)) == nil)

        // All windows should be cleared (since it includes app1)
        #expect(await cache.get(.allWindows(options: .default)) == nil)
    }

    @Test("Clears all entries")
    func testClear() async {
        let cache = WindowCache()

        await cache.set(.allWindows(options: .default), windows: [makeTestWindow(id: 1)])
        await cache.set(.processID(100, options: .default), windows: [makeTestWindow(id: 2)])

        await cache.clear()

        #expect(await cache.get(.allWindows(options: .default)) == nil)
        #expect(await cache.get(.processID(100, options: .default)) == nil)

        let stats = await cache.statistics()
        #expect(stats.entryCount == 0)
    }

    @Test("Prunes expired entries")
    func testPruneExpired() async throws {
        let cache = WindowCache(defaultTTL: 0.1) // 100ms TTL

        await cache.set(.allWindows(options: .default), windows: [makeTestWindow(id: 1)])
        await cache.set(.processID(100, options: .default), windows: [makeTestWindow(id: 2)])

        // Wait for expiration
        try await Task.sleep(for: .milliseconds(150))

        // Add fresh entry
        await cache.set(.processID(200, options: .default), windows: [makeTestWindow(id: 3)], ttl: 10.0)

        // Prune
        await cache.pruneExpired()

        let stats = await cache.statistics()
        #expect(stats.entryCount == 1) // Only fresh entry remains
    }

    @Test("Tracks hit/miss statistics")
    func testStatistics() async {
        let cache = WindowCache()
        let key = CacheKey.allWindows(options: .default)

        // Initial stats
        var stats = await cache.statistics()
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)
        #expect(stats.hitRate == 0.0)

        // Miss
        _ = await cache.get(key)
        stats = await cache.statistics()
        #expect(stats.misses == 1)

        // Set and hit
        await cache.set(key, windows: [makeTestWindow(id: 1)])
        _ = await cache.get(key)

        stats = await cache.statistics()
        #expect(stats.hits == 1)
        #expect(stats.misses == 1)
        #expect(stats.hitRate == 0.5)
    }

    @Test("Resets statistics")
    func testResetStatistics() async {
        let cache = WindowCache()
        let key = CacheKey.allWindows(options: .default)

        // Generate some stats
        _ = await cache.get(key)
        await cache.set(key, windows: [makeTestWindow(id: 1)])
        _ = await cache.get(key)

        var stats = await cache.statistics()
        #expect(stats.hits > 0)

        // Reset
        await cache.resetStatistics()

        stats = await cache.statistics()
        #expect(stats.hits == 0)
        #expect(stats.misses == 0)
    }

    @Test("Different options create different cache keys")
    func testDifferentOptions() async {
        let cache = WindowCache()

        var options1 = WindowDiscoveryOptions.default
        var options2 = WindowDiscoveryOptions.default
        options2.includeHidden = true

        await cache.set(.allWindows(options: options1), windows: [makeTestWindow(id: 1)])
        await cache.set(.allWindows(options: options2), windows: [makeTestWindow(id: 2)])

        let result1 = await cache.get(.allWindows(options: options1))
        let result2 = await cache.get(.allWindows(options: options2))

        #expect(result1?[0].id == 1)
        #expect(result2?[0].id == 2)
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
