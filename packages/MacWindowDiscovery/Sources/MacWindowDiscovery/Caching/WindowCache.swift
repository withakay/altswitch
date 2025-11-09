import Foundation

/// Thread-safe cache for window discovery results
///
/// Uses TTL (Time To Live) to automatically expire entries and
/// supports manual invalidation for event-driven cache management.
actor WindowCache {

    // MARK: - Properties

    private var cache: [CacheKey: CacheEntry] = [:]
    private let defaultTTL: TimeInterval

    /// Cache statistics
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0

    // MARK: - Initialization

    /// Create a new cache with default TTL
    /// - Parameter defaultTTL: Time to live in seconds (default: 1.0)
    init(defaultTTL: TimeInterval = 1.0) {
        self.defaultTTL = defaultTTL
    }

    // MARK: - Cache Operations

    /// Get cached windows if available and not expired
    func get(_ key: CacheKey) -> [WindowInfo]? {
        guard let entry = cache[key] else {
            misses += 1
            return nil
        }

        if entry.isExpired {
            cache.removeValue(forKey: key)
            misses += 1
            return nil
        }

        hits += 1
        return entry.windows
    }

    /// Store windows in cache
    func set(_ key: CacheKey, windows: [WindowInfo], ttl: TimeInterval? = nil) {
        let entry = CacheEntry(windows: windows, ttl: ttl ?? defaultTTL)
        cache[key] = entry
    }

    /// Invalidate specific cache entry
    func invalidate(_ key: CacheKey) {
        cache.removeValue(forKey: key)
    }

    /// Invalidate all entries for a specific process
    func invalidateProcess(_ pid: pid_t) {
        let keysToRemove = cache.keys.filter { key in
            switch key {
            case .processID(let cachedPid, _):
                return cachedPid == pid
            case .allWindows:
                return true // All windows cache includes this process
            case .bundleIdentifier:
                return true // Bundle ID cache might include this process
            }
        }

        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }

    /// Invalidate all entries for a specific bundle identifier
    func invalidateBundleIdentifier(_ bundleID: String) {
        let keysToRemove = cache.keys.filter { key in
            switch key {
            case .bundleIdentifier(let cachedBundle, _):
                return cachedBundle == bundleID
            case .allWindows:
                return true // All windows cache includes this app
            case .processID:
                return true // Process cache might be this app
            }
        }

        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }

    /// Clear all cached entries
    func clear() {
        cache.removeAll()
    }

    /// Remove expired entries
    func pruneExpired() {
        let expiredKeys = cache.filter { $0.value.isExpired }.map { $0.key }
        for key in expiredKeys {
            cache.removeValue(forKey: key)
        }
    }

    // MARK: - Statistics

    /// Get cache statistics
    func statistics() -> CacheStatistics {
        let total = hits + misses
        let hitRate = total > 0 ? Double(hits) / Double(total) : 0.0

        return CacheStatistics(
            hits: hits,
            misses: misses,
            hitRate: hitRate,
            entryCount: cache.count
        )
    }

    /// Reset statistics
    public func resetStatistics() {
        hits = 0
        misses = 0
    }
}

// MARK: - Statistics

/// Cache performance statistics
public struct CacheStatistics: Sendable {
    public let hits: Int
    public let misses: Int
    public let hitRate: Double
    public let entryCount: Int
}
