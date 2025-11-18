import CoreGraphics
import Foundation

/// Window discovery engine with caching support
///
/// Wraps WindowDiscoveryEngine with automatic caching and event-driven
/// invalidation for improved performance when discovering windows multiple times.
public final class CachedWindowDiscoveryEngine: Sendable {

    // MARK: - Properties

    private let engine: WindowDiscoveryEngine
    private let cache: WindowCache
    private let monitor: WindowEventMonitor?
    private let enableAutoInvalidation: Bool

    // MARK: - Initialization

    /// Create a cached discovery engine
    /// - Parameters:
    ///   - engine: Underlying discovery engine (defaults to new instance)
    ///   - cacheTTL: Time to live for cache entries in seconds (default: 5.0)
    ///   - enableAutoInvalidation: Enable event-driven cache invalidation (default: true)
    @MainActor
    public init(
        engine: WindowDiscoveryEngine = WindowDiscoveryEngine(),
        cacheTTL: TimeInterval = 5.0,
        enableAutoInvalidation: Bool = true
    ) {
        self.engine = engine
        self.cache = WindowCache(defaultTTL: cacheTTL)
        self.enableAutoInvalidation = enableAutoInvalidation

        if enableAutoInvalidation {
            let monitor = WindowEventMonitor(cache: cache)
            monitor.start()
            self.monitor = monitor
        } else {
            self.monitor = nil
        }
    }

    /// Create a cached engine with custom components (for testing)
    @MainActor
    init(
        engine: WindowDiscoveryEngine,
        cache: WindowCache,
        monitor: WindowEventMonitor?
    ) {
        self.engine = engine
        self.cache = cache
        self.monitor = monitor
        self.enableAutoInvalidation = monitor != nil
    }

    // MARK: - Discovery Operations

    /// Discover all windows matching the given options
    ///
    /// Results are cached based on options. Subsequent calls with the same
    /// options will return cached results if available and not expired.
    nonisolated public func discoverWindows(
        options: WindowDiscoveryOptions = .default
    ) async throws -> [WindowInfo] {
        let key = CacheKey.allWindows(options: options)

        // Check cache first
        if let cached = await cache.get(key) {
            return cached
        }

        // Perform discovery
        let windows = try await engine.discoverWindows(options: options)
        
        // Cache AX elements if enabled
        if options.enableAXElementCaching {
            await AXElementStore.shared.cacheElements(for: windows)
        }

        // Store in cache
        await cache.set(key, windows: windows)

        return windows
    }

    /// Discover windows for a specific process
    nonisolated public func discoverWindows(
        forProcessID processID: pid_t,
        options: WindowDiscoveryOptions = .default
    ) async throws -> [WindowInfo] {
        let key = CacheKey.processID(processID, options: options)

        // Check cache first
        if let cached = await cache.get(key) {
            return cached
        }

        // Perform discovery
        let windows = try await engine.discoverWindows(forProcessID: processID, options: options)
        
        // Cache AX elements if enabled
        if options.enableAXElementCaching {
            await AXElementStore.shared.cacheElements(for: windows)
        }

        // Store in cache
        await cache.set(key, windows: windows)

        return windows
    }

    /// Discover windows for a specific application
    nonisolated public func discoverWindows(
        forBundleIdentifier bundleIdentifier: String,
        options: WindowDiscoveryOptions = .default
    ) async throws -> [WindowInfo] {
        let key = CacheKey.bundleIdentifier(bundleIdentifier, options: options)

        // Check cache first
        if let cached = await cache.get(key) {
            return cached
        }

        // Perform discovery
        let windows = try await engine.discoverWindows(
            forBundleIdentifier: bundleIdentifier,
            options: options
        )

        // Store in cache
        await cache.set(key, windows: windows)

        return windows
    }

    // MARK: - Cache Management

    /// Manually invalidate cache for a specific process
    public func invalidateCache(forProcessID pid: pid_t) async {
        await cache.invalidateProcess(pid)
    }

    /// Manually invalidate cache for a specific bundle identifier
    public func invalidateCache(forBundleIdentifier bundleID: String) async {
        await cache.invalidateBundleIdentifier(bundleID)
    }

    /// Clear all cached entries
    public func clearCache() async {
        await cache.clear()
    }

    /// Remove expired entries from cache
    public func pruneCache() async {
        await cache.pruneExpired()
    }

    /// Get cache statistics
    public func cacheStatistics() async -> CacheStatistics {
        await cache.statistics()
    }

    /// Reset cache statistics
    public func resetStatistics() async {
        await cache.resetStatistics()
    }

    // MARK: - Event Monitoring

    /// Stop event monitoring (if enabled)
    @MainActor
    public func stopMonitoring() {
        monitor?.stop()
    }

    /// Restart event monitoring (if enabled)
    @MainActor
    public func startMonitoring() {
        monitor?.start()
    }

    /// Register a handler to be called when cache invalidation events occur
    /// - Parameter handler: Closure called on MainActor when events occur
    @MainActor
    public func onInvalidation(_ handler: @escaping @Sendable (InvalidationEvent) -> Void) {
        monitor?.addHandler(handler)
    }

    // MARK: - Permission Checking

    /// Check if accessibility permissions are granted
    public static func hasAccessibilityPermission() -> Bool {
        WindowDiscoveryEngine.hasAccessibilityPermission()
    }

    /// Request accessibility permissions (shows system dialog)
    @MainActor
    @discardableResult
    public static func requestAccessibilityPermission() -> Bool {
        WindowDiscoveryEngine.requestAccessibilityPermission()
    }

    /// Check if screen recording permission is granted
    public static func hasScreenRecordingPermission() -> Bool {
        WindowDiscoveryEngine.hasScreenRecordingPermission()
    }
}
