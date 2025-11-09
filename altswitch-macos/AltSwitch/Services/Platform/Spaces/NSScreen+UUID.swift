//
//  NSScreen+UUID.swift
//  AltSwitch
//
//  NSScreen extension for UUID and display management
//  Ported from AltTab: https://github.com/lwouis/alt-tab-macos
//

import AppKit
import CoreGraphics
import Foundation

extension NSScreen {
  /// Get the UUID for this screen
  /// - Returns: Screen UUID if available
  func uuid() -> ScreenUuid? {
    guard let screenNumber = number(),
          let screenUuid = CGDisplayCreateUUIDFromDisplayID(screenNumber),
          let uuid = CFUUIDCreateString(nil, screenUuid.takeRetainedValue()) else {
      return nil
    }
    return uuid
  }

  /// Get the display ID (number) for this screen
  /// - Returns: Display ID
  func number() -> CGDirectDisplayID? {
    return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
  }

  /// Get the screen with the active menubar (primary display)
  /// - Returns: Screen with menubar, or main screen as fallback
  static func withActiveMenubar() -> NSScreen? {
    let activeMenubarUuid = CGSCopyActiveMenuBarDisplayIdentifier(CGS_CONNECTION)
    return NSScreen.screens.first { $0.uuid() == activeMenubarUuid } ?? NSScreen.main
  }

  /// Check if screens have separate spaces enabled in System Preferences
  /// - Returns: True if "Displays have separate Spaces" is enabled
  static var screensHaveSeparateSpaces: Bool {
    // Check the system preference
    // This is a macOS system setting that affects how spaces work across displays
    return NSScreen.screens.count > 1 &&
           UserDefaults.standard.bool(forKey: "spans-displays") == false
  }
}
