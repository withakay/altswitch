import Foundation

/// A cached result with timestamp
struct CacheEntry: Sendable {
    let windows: [WindowInfo]
    let timestamp: Date
    let ttl: TimeInterval

    /// Check if this entry has expired
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }

    /// Time remaining before expiration (nil if already expired)
    var timeRemaining: TimeInterval? {
        let remaining = ttl - Date().timeIntervalSince(timestamp)
        return remaining > 0 ? remaining : nil
    }

    init(windows: [WindowInfo], ttl: TimeInterval = 1.0) {
        self.windows = windows
        self.timestamp = Date()
        self.ttl = ttl
    }
}
