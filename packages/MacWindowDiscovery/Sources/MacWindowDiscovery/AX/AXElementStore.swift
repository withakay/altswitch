import Foundation
import ApplicationServices

/// Thread-confined AX element cache.
@MainActor
public final class AXElementStore {
    public static let shared = AXElementStore()

    private var cache: [CGWindowID: AXUIElement] = [:]

    private init() {}

    public func set(_ element: AXUIElement, for windowID: CGWindowID) {
        cache[windowID] = element
    }

    public func get(for windowID: CGWindowID) -> AXUIElement? {
        return cache[windowID]
    }

    public func remove(for windowID: CGWindowID) {
        cache.removeValue(forKey: windowID)
    }

    public func clear() {
        cache.removeAll()
    }

    public var count: Int { cache.count }
}

