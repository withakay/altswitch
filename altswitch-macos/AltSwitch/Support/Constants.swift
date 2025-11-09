//
//  AltSwitchConstants.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import AppKit
import Foundation
import KeyboardShortcuts

/// Global constants for the AltSwitch application
enum AltSwitchConstants {
  // MARK: - Hotkey
  static let defaultHotkey = KeyCombo.defaultShowHide()

  // MARK: - Search
  static let maxSearchResults = 10
  static let searchDebounceMilliseconds = 50

  // MARK: - Refresh Intervals
  static let windowRefreshInterval: TimeInterval = 0.5
  static let appDiscoveryInterval: TimeInterval = 2.0

  // MARK: - Animation
  static let animationDuration: TimeInterval = 0.2
  static let springResponse: Double = 0.3
  static let springDamping: Double = 0.8

  // MARK: - Window Dimensions
  static let windowWidth: CGFloat = 600
  static let windowHeight: CGFloat = 800
  static let windowCornerRadius: CGFloat = 12
  static let windowPadding: CGFloat = 20

  // MARK: - UI Sizes
  static let appIconSize: CGFloat = 32
  static let rowHeight: CGFloat = 48  // Fixed row height for consistent window sizing
  static let searchFieldHeight: CGFloat = 36
  static let searchContainerHeight: CGFloat = searchFieldHeight + 52  // Search field plus surrounding padding
  static let listRowSpacing: CGFloat = 4

  // MARK: - Window Layout Ratios
  static let windowVerticalMarginRatio: CGFloat = 0.1  // 10% from top and bottom
  static let windowMaxHeightRatio: CGFloat = 1 - (2 * windowVerticalMarginRatio)  // 80% max height

  // MARK: - Colors (for non-SwiftUI contexts)
  static let backgroundColor = NSColor(white: 0.0, alpha: 0.8)
  static let highlightColor = NSColor.controlAccentColor
  static let textColor = NSColor.labelColor
  static let secondaryTextColor = NSColor.secondaryLabelColor

  // MARK: - File Paths
  static var configDirectory: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".config")
      .appendingPathComponent("altswitch")
  }

  static var settingsFilePath: URL {
    configDirectory.appendingPathComponent("settings.yaml")
  }

  // MARK: - Accessibility
  static let accessibilityCheckDelay: TimeInterval = 0.5
  static let maxAccessibilityRetries = 3

  // MARK: - Performance
  static let maxConcurrentOperations = 4
  static let cacheExpirationInterval: TimeInterval = 60.0  // 1 minute
}
