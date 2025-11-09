//
//  Spaces.swift
//  AltSwitch
//
//  Spaces management and tracking across multiple displays
//  Ported from AltTab: https://github.com/lwouis/alt-tab-macos
//

import AppKit
import Foundation

typealias SpaceIndex = Int

/// Manages space (desktop) tracking across all displays
@MainActor
class Spaces {
  nonisolated(unsafe) static var currentSpaceId = CGSSpaceID(1)
  nonisolated(unsafe) static var currentSpaceIndex = SpaceIndex(1)
  nonisolated(unsafe) static var visibleSpaces = [CGSSpaceID]()
  nonisolated(unsafe) static var screenSpacesMap = [ScreenUuid: [CGSSpaceID]]()  // Maps display UUID to space IDs
  nonisolated(unsafe) static var idsAndIndexes = [(CGSSpaceID, SpaceIndex)]()    // Maps space IDs to UI indices

  /// Refresh all space information from the system
  static func refresh() {
    refreshAllIdsAndIndexes()
    updateCurrentSpace()
  }

  /// Update tracking of the current active space
  private static func updateCurrentSpace() {
    if let mainScreen = NSScreen.main,
       let uuid = mainScreen.uuid() {
      currentSpaceId = CGSManagedDisplayGetCurrentSpace(CGS_CONNECTION, uuid)
    }

    // Find the index of the current space
    if let index = idsAndIndexes.firstIndex(where: { $0.0 == currentSpaceId }) {
      currentSpaceIndex = idsAndIndexes[index].1
    }
  }

  /// Parse all spaces from the system and build our tracking structures
  private static func refreshAllIdsAndIndexes() {
    idsAndIndexes.removeAll()
    screenSpacesMap.removeAll()
    visibleSpaces.removeAll()

    var spaceIndex = SpaceIndex(1)

    // Get all displays and their associated spaces
    guard let managedSpaces = CGSCopyManagedDisplaySpaces(CGS_CONNECTION) as? [NSDictionary] else {
      return
    }

    for screen in managedSpaces {
      guard let displayUuid = screen["Display Identifier"],
            CFGetTypeID(displayUuid as CFTypeRef) == CFStringGetTypeID(),
            let spaces = screen["Spaces"] as? [NSDictionary] else {
        continue
      }

      let screenUuid = displayUuid as! ScreenUuid

      for space in spaces {
        guard let spaceId = space["id64"] as? CGSSpaceID else {
          continue
        }

        idsAndIndexes.append((spaceId, spaceIndex))
        screenSpacesMap[screenUuid, default: []].append(spaceId)

        // Track currently visible spaces
        if let type = space["type"] as? Int, type == 0 {  // 0 = user space (not fullscreen)
          visibleSpaces.append(spaceId)
        }

        spaceIndex += 1
      }
    }
  }

  /// Get all window IDs that are visible in specific spaces
  /// - Parameters:
  ///   - spaceIds: Array of space IDs to query
  ///   - includeInvisible: Whether to include invisible windows
  /// - Returns: Array of window IDs
  static func windowsInSpaces(_ spaceIds: [CGSSpaceID], _ includeInvisible: Bool = true) -> [CGWindowID] {
    var setTags = ([] as CGSCopyWindowsTags).rawValue
    var clearTags = ([] as CGSCopyWindowsTags).rawValue
    var options = [CGSCopyWindowsOptions.screenSaverLevel1000]

    if includeInvisible {
      options.append(.invisible1)
      options.append(.invisible2)
    }

    let optionsValue = options.reduce(0) { $0 | $1.rawValue }

    return CGSCopyWindowsWithOptionsAndTags(
      CGS_CONNECTION,
      0,
      spaceIds as CFArray,
      optionsValue,
      &setTags,
      &clearTags
    ) as! [CGWindowID]
  }

  /// Initialize spaces tracking - call this at app startup
  static func initialize() {
    refresh()

    // Observe space change notifications
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: nil,
      queue: .main
    ) { _ in
      Spaces.refresh()
    }
  }
}
