#!/usr/bin/env swift

import AppKit
import Foundation

// Test script to verify main display detection
print("=== Main Display Test ===")

// Get all screens
let screens = NSScreen.screens
print("Total screens: \(screens.count)")

// Print details about each screen
for (index, screen) in screens.enumerated() {
  print("Screen \(index + 1):")
  print("  Frame: \(screen.frame)")
  print("  Visible Frame: \(screen.visibleFrame)")
  if screen == NSScreen.main {
    print("  ** MAIN SCREEN **")
  }
  print()
}

// Get main screen details
if let mainScreen = NSScreen.main {
  print("Main screen visible frame: \(mainScreen.visibleFrame)")

  // Calculate center position for a 600x800 window
  let windowSize = NSSize(width: 600, height: 800)
  let screenFrame = mainScreen.visibleFrame
  let centerX = screenFrame.minX + (screenFrame.width - windowSize.width) / 2
  let centerY = screenFrame.minY + (screenFrame.height - windowSize.height) / 2
  let centerPoint = NSPoint(x: centerX, y: centerY)

  print("Calculated window center position: \(centerPoint)")
} else {
  print("WARNING: No main screen found!")
}
