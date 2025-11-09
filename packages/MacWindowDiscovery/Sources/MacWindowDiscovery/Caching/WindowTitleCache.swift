import Foundation
import CoreGraphics

/// Thread-safe FIFO cache for window titles
/// Maintains a fixed-size cache of window titles, evicting oldest entries when full
public actor WindowTitleCache {

    private var titles: [CGWindowID: String] = [:]
    private var fifoQueue: [CGWindowID] = []
    private let maxSize: Int

    /// Create a new title cache
    /// - Parameter maxSize: Maximum number of titles to cache (default: 100)
    public init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    /// Store a window title in the cache
    /// - Parameters:
    ///   - windowID: The window ID
    ///   - title: The window title
    public func set(windowID: CGWindowID, title: String) {
        guard !title.isEmpty else { return }

        // If already exists, move to end of queue (most recently used)
        if titles[windowID] != nil {
            fifoQueue.removeAll { $0 == windowID }
        }

        titles[windowID] = title
        fifoQueue.append(windowID)

        // Evict oldest if over limit
        if fifoQueue.count > maxSize {
            let oldest = fifoQueue.removeFirst()
            titles.removeValue(forKey: oldest)
        }
    }

    /// Retrieve a cached window title
    /// - Parameter windowID: The window ID
    /// - Returns: The cached title, or nil if not found
    public func get(windowID: CGWindowID) -> String? {
        return titles[windowID]
    }

    /// Remove a window from the cache
    /// - Parameter windowID: The window ID to remove
    public func remove(windowID: CGWindowID) {
        titles.removeValue(forKey: windowID)
        fifoQueue.removeAll { $0 == windowID }
    }

    /// Clear all cached titles
    public func clear() {
        titles.removeAll()
        fifoQueue.removeAll()
    }

    /// Get current cache size
    public var count: Int {
        return titles.count
    }
}
