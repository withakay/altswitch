//
//  AXElementCache.swift
//  AltSwitch
//
//  Caches AXUIElement references for windows discovered during app discovery
//  Critical for cross-space window switching - we must cache the AXUIElement
//  when the window is first discovered (accessible) for later use when switching
//  to a window on another space (inaccessible via normal AX API).
//
//  This matches AltTab's approach of storing axUiElement in the Window object.
//

import ApplicationServices
import Foundation

/// Thread-safe cache for AXUIElement references mapped by CGWindowID
@MainActor
final class AXElementCache {
  /// Singleton instance
  static let shared = AXElementCache()

  /// Map of window ID to AXUIElement
  private var cache: [CGWindowID: AXUIElement] = [:]

  private init() {}

  /// Cache an AXUIElement for a window
  func set(_ element: AXUIElement, for windowID: CGWindowID) {
    cache[windowID] = element
    NSLog("AXElementCache: Cached AXUIElement for window \(windowID)")
  }

  /// Retrieve cached AXUIElement for a window
  func get(for windowID: CGWindowID) -> AXUIElement? {
    let element = cache[windowID]
    if element != nil {
      NSLog("AXElementCache: Retrieved cached AXUIElement for window \(windowID)")
    } else {
      NSLog("AXElementCache: No cached AXUIElement for window \(windowID)")
    }
    return element
  }

  /// Remove cached element for a window (e.g., when window closes)
  func remove(for windowID: CGWindowID) {
    cache.removeValue(forKey: windowID)
    NSLog("AXElementCache: Removed cached AXUIElement for window \(windowID)")
  }

  /// Clear all cached elements
  func clear() {
    let count = cache.count
    cache.removeAll()
    NSLog("AXElementCache: Cleared \(count) cached AXUIElements")
  }

  /// Get cache statistics for debugging
  var count: Int {
    cache.count
  }
}
