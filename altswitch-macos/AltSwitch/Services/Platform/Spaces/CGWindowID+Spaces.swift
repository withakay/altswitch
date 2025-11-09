//
//  CGWindowID+Spaces.swift
//  AltSwitch
//
//  CGWindowID extension for space detection
//  Ported from AltTab: https://github.com/lwouis/alt-tab-macos
//

import AppKit
import CoreGraphics
import Foundation

extension CGWindowID {
  /// Get all space IDs that this window appears on
  /// - Returns: Array of space IDs
  func spaces() -> [CGSSpaceID] {
    return CGSCopySpacesForWindows(
      CGS_CONNECTION,
      CGSSpaceMask.all.rawValue,
      [self] as CFArray
    ) as! [CGSSpaceID]
  }

  /// Check if this window is on all spaces (sticky window)
  /// - Returns: True if window appears on multiple spaces
  func isOnAllSpaces() -> Bool {
    return spaces().count > 1
  }

  /// Check if this window is on the current space
  /// - Returns: True if window is visible on current space
  func isOnCurrentSpace() -> Bool {
    let windowSpaces = spaces()
    return windowSpaces.contains(Spaces.currentSpaceId)
  }

  /// Check if this window is on a specific screen's spaces
  /// - Parameter screen: The screen to check
  /// - Returns: True if window is on any of the screen's spaces
  func isOnScreen(_ screen: NSScreen) -> Bool {
    guard NSScreen.screensHaveSeparateSpaces,
          let screenUuid = screen.uuid(),
          let screenSpaces = Spaces.screenSpacesMap[screenUuid] else {
      return true  // If we can't determine, assume true
    }

    let windowSpaces = spaces()
    return screenSpaces.contains { screenSpace in
      windowSpaces.contains { $0 == screenSpace }
    }
  }
}
