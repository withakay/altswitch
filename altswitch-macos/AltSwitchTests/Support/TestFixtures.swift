//
//  TestFixtures.swift
//  AltSwitchTests
//
//  Shared test helpers for deterministic data.
//

import AppKit
import MacWindowDiscovery

@testable import AltSwitch

enum TestFixtures {
  static func icon(size: CGFloat = 32) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSColor(calibratedRed: 0.24, green: 0.56, blue: 0.89, alpha: 1.0).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: NSSize(width: size, height: size))).fill()
    image.unlockFocus()
    return image
  }

  static func window(
    id: CGWindowID,
    title: String,
    isOnScreen: Bool = true,
    alpha: Float = 1.0
  ) -> MacWindowDiscovery.WindowInfo {
    MacWindowDiscovery.WindowInfo(
      id: id,
      title: title,
      bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
      alpha: Double(alpha),
      isOnScreen: isOnScreen,
      layer: 0,
      processID: 0,
      bundleIdentifier: nil,
      applicationName: title,
      isMinimized: false,
      isHidden: false,
      isFullscreen: false,
      isFocused: false,
      isMainWindow: true,
      isTabbed: false,
      spaceIDs: [],
      isOnAllSpaces: false,
      desktopNumber: nil,
      displayID: 0,
      role: nil,
      subrole: nil,
      capturedAt: Date()
    )
  }

  static func app(
    bundleIdentifier: String,
    name: String,
    pid: pid_t,
    isHidden: Bool = false,
    isActive: Bool = false,
    windows: [MacWindowDiscovery.WindowInfo] = []
  ) -> AltSwitch.AppInfo {
    AltSwitch.AppInfo(
      bundleIdentifier: bundleIdentifier,
      localizedName: name,
      processIdentifier: pid,
      icon: icon(),
      isActive: isActive,
      isHidden: isHidden,
      windows: windows
    )
  }
}
