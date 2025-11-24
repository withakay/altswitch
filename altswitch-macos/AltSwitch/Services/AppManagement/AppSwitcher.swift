//
//  AppSwitcher.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import AppKit
import Foundation
import MacWindowDiscovery
import MacWindowSwitch

/// Main actor-isolated app switcher implementation
@MainActor
final class AppSwitcher: AppSwitcherProtocol {
  static let shared = AppSwitcher()

  /// Dedicated operation queue for window focus commands (matching AltTab's approach)
  /// Uses .userInteractive QoS with max 4 concurrent operations
  nonisolated private static let focusQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.qualityOfService = .userInteractive
    queue.maxConcurrentOperationCount = 4
    queue.name = "com.thoughtsun.altswitch.focusQueue"
    return queue
  }()

  init() {
    // Background AX warm-up at startup. Non-blocking and time-bounded.
    Task.detached {
      await AXWarmup.warmUpAXCacheForAllRunningApps(timeoutPerAppMs: 50, maxConcurrent: 3)
      await AXWarmup.warmUpTitlesForRunningAndRange(
        pidRange: 1...10_000,
        maxElementID: 2_000,
        timeBudgetMsPerPID: 40,
        maxConcurrent: 3
      )
    }
  }

  /// Dependencies for window-ID-only activation path (PID/AX resolvers)
  nonisolated private static var activationDependencies: ActivationDependencies {
    ActivationDependencies(
      pidResolver: { windowID in
        WindowIdentityResolver().resolveProcessID(for: windowID)
      },
      axResolver: { windowID in
        MacWindowDiscovery.AXElementStore.shared.get(for: windowID)
      }
    )
  }

  /// Switch to the specified application and bring it to front
  /// Uses AltTab's proven space-switching approach
  func switchTo(_ app: AppInfo) async throws {
    guard !app.windows.isEmpty, let cgWindowId = app.windows.first?.id else {
      throw AltSwitchError.appNotFound(bundleID: app.bundleIdentifier)
    }

    NSLog("AltSwitch: Switching to window \(cgWindowId) for app \(app.localizedName)")

    // CRITICAL: Wait a moment for AltSwitch window to hide before focusing new window
    // This ensures AltSwitch doesn't interfere with space switching
    try await Task.sleep(nanoseconds: 50_000_000) // 50ms

    // Fire and forget - space switch happens asynchronously
    focusWindow(pid: app.processIdentifier, cgWindowId: CGWindowID(cgWindowId))
  }

  /// Focus a specific window using MacWindowSwitch package
  /// CRITICAL: Fire-and-forget like AltTab - don't wait for completion, space switch happens async
  nonisolated private func focusWindow(pid: pid_t, cgWindowId: CGWindowID) {
    Self.focusQueue.addOperation { [weak self] in
      guard let self else { return }

      NSLog("AltSwitch: focusWindow START - pid: \(pid), windowId: \(cgWindowId)")

      // STEP 1: Use MacWindowSwitch for core activation (handles SkyLight + HIServices strategies)
      // New path: activate by window ID only with resolvers; this enables cross-space activation without prior "seen" state
      do {
        try WindowActivator.activate(windowID: cgWindowId, dependencies: Self.activationDependencies)
      } catch {
        NSLog("AltSwitch: ❌ WindowActivator.activate(windowID:dependencies:) failed: \(error)")
      }

      // STEP 2: Basic app activation if needed (unhide hidden apps)
      // Do this AFTER private APIs so we don't interfere with specific window targeting
      if let targetApp = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
        // Unhide if hidden
        if targetApp.isHidden {
          NSLog("AltSwitch: App is hidden, unhiding...")
          targetApp.unhide()
        }
      }

      // STEP 3: Wait for space switch to complete
      // CRITICAL: Space switching takes 500-1000ms. If we try to access AX windows
      // before the switch completes, we'll find 0 windows (still on old space).
      NSLog("AltSwitch: Waiting 800ms for space switch to complete...")
      Thread.sleep(forTimeInterval: 0.8)

      // STEP 4: Use AX API to finalize focus
      // CRITICAL: The private APIs switch spaces, but the AX API ensures the specific
      // window is raised. Without this, multi-window apps activate the wrong window!
      NSLog("AltSwitch: Calling AX API to finalize focus...")
      try? self.axFocusWindow(pid: pid, cgWindowId: cgWindowId)

      NSLog("AltSwitch: ✅ Window focus complete")

      // Optional - schedule UI update on main thread after delay (like AltTab)
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
        NSLog("AltSwitch: Post-focus UI update (50ms after focus)")
      }
    }
  }

  /// Use accessibility API to focus window (from AltTab)
  /// CRITICAL: Uses cached AXUIElement from AXElementStore for cross-space switching
  /// CRITICAL: This runs SYNCHRONOUSLY on main thread to ensure window is raised before returning
  nonisolated private func axFocusWindow(pid: pid_t, cgWindowId: CGWindowID) throws {
    // CRITICAL: Try to use cached AXUIElement first (for cross-space windows)
    // This is the key difference from our previous approach - AltTab caches the
    // AXUIElement when the window is discovered (accessible), then uses it later
    // when switching to a window on another space (inaccessible).
    // Use DispatchQueue.main.sync to block until AX operations complete (like AltTab)
    DispatchQueue.main.sync {
      if let cachedElement = MacWindowDiscovery.AXElementStore.shared.get(for: cgWindowId) {
        NSLog("AltSwitch: ✅ Using CACHED AXUIElement for window \(cgWindowId)")
        let appElement = AXUIElementCreateApplication(pid)

        // Perform raise action with error checking
        let raiseResult = AXUIElementPerformAction(cachedElement, kAXRaiseAction as CFString)
        NSLog("AltSwitch: kAXRaiseAction result: \(raiseResult.rawValue) (\(raiseResult == .success ? "SUCCESS" : "FAILED"))")

        // Set as main window with error checking
        let setMainResult = AXUIElementSetAttributeValue(appElement, kAXMainWindowAttribute as CFString, cachedElement)
        NSLog("AltSwitch: kAXMainWindowAttribute result: \(setMainResult.rawValue) (\(setMainResult == .success ? "SUCCESS" : "FAILED"))")

        NSLog("AltSwitch: ✅ Window raised and set as main using cached element")
        return
      }

      // Fallback: Try to find the window dynamically (will fail for cross-space windows)
      NSLog("AltSwitch: ⚠️ No cached AXUIElement for window \(cgWindowId), trying dynamic lookup")
      let appElement = AXUIElementCreateApplication(pid)
      var windows: CFTypeRef?
      let axResult = AXUIElementCopyAttributeValue(
        appElement, kAXWindowsAttribute as CFString, &windows)

      guard axResult == .success else {
        NSLog("AltSwitch: ❌ AXUIElementCopyAttributeValue failed: \(axResult.rawValue)")
        return
      }

      guard let windowArray = windows as? [AXUIElement] else {
        NSLog("AltSwitch: ❌ Could not cast windows to [AXUIElement]")
        return
      }

      NSLog("AltSwitch: Found \(windowArray.count) AX windows for pid \(pid)")

      for (index, axWindow) in windowArray.enumerated() {
        var axWindowIdValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, "_AXWindowID" as CFString, &axWindowIdValue)

        if result == .success, let windowIdNumber = axWindowIdValue as? UInt32 {
          NSLog("AltSwitch: Window[\(index)] ID: \(windowIdNumber) (looking for \(cgWindowId))")
          if windowIdNumber == cgWindowId {
            NSLog("AltSwitch: ✅ Found matching window! Raising and setting as main...")

            // Perform raise action with error checking
            let raiseResult = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
            NSLog("AltSwitch: kAXRaiseAction result: \(raiseResult.rawValue) (\(raiseResult == .success ? "SUCCESS" : "FAILED"))")

            // Set as main window with error checking
            let setMainResult = AXUIElementSetAttributeValue(appElement, kAXMainWindowAttribute as CFString, axWindow)
            NSLog("AltSwitch: kAXMainWindowAttribute result: \(setMainResult.rawValue) (\(setMainResult == .success ? "SUCCESS" : "FAILED"))")

            NSLog("AltSwitch: ✅ Window raised and set as main")
            return
          }
        }
      }

      NSLog("AltSwitch: ❌ Did not find window with ID \(cgWindowId) in AX windows")
    }
  }

  /// Bring the specified application to the front without activating it
  func bringToFront(_ app: AppInfo) async throws {
    // This operation requires accessibility permissions for window manipulation
    guard AXIsProcessTrusted() else {
      // Fallback to basic activation if no permissions
      try await switchTo(app)
      return
    }

    // Find the running application
    let runningApps = NSWorkspace.shared.runningApplications
    guard
      let targetApp = runningApps.first(where: { $0.processIdentifier == app.processIdentifier })
    else {
      throw AltSwitchError.appNotFound(bundleID: app.bundleIdentifier)
    }

    // Check if the app is actually running
    guard targetApp.isFinishedLaunching else {
      throw AltSwitchError.appNotFound(bundleID: app.bundleIdentifier)
    }

    // Use AXUIElement to bring windows to front without activating
    let appElement = AXUIElementCreateApplication(app.processIdentifier)

    // Check if we're targeting a specific window
    if !app.windows.isEmpty {
      let targetWindow = app.windows[0]

      // Find the window by matching title
      var windows: CFTypeRef?
      let result = AXUIElementCopyAttributeValue(
        appElement, kAXWindowsAttribute as CFString, &windows
      )

      if result == .success, let windowArray = windows as? [AXUIElement] {
        // Try to find the specific window by title
        for axWindow in windowArray {
          var titleValue: CFTypeRef?
          if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
            == .success,
            let title = titleValue as? String,
            title == targetWindow.title
          {
            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
            return
          }
        }

        // If no match found, raise the first window as fallback
        if !windowArray.isEmpty {
          AXUIElementPerformAction(windowArray[0], kAXRaiseAction as CFString)
        }
      } else if result != .success {
        throw AltSwitchError.appDiscoveryFailed(
          underlying: NSError(
            domain: "AppSwitcher",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to access application windows"]
          )
        )
      }
    } else {
      // No specific window - bring all windows to front
      var windows: CFTypeRef?
      let result = AXUIElementCopyAttributeValue(
        appElement, kAXWindowsAttribute as CFString, &windows
      )

      if result == .success, let windowArray = windows as? [AXUIElement] {
        // Bring all windows to front
        for window in windowArray {
          AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
      } else if result != .success {
        throw AltSwitchError.appDiscoveryFailed(
          underlying: NSError(
            domain: "AppSwitcher",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to access application windows"]
          )
        )
      }
    }
  }

  /// Unhide a hidden application
  func unhide(_ app: AppInfo) async throws {
    // Find the running application
    let runningApps = NSWorkspace.shared.runningApplications
    guard
      let targetApp = runningApps.first(where: { $0.processIdentifier == app.processIdentifier })
    else {
      throw AltSwitchError.appNotFound(bundleID: app.bundleIdentifier)
    }

    // Check if the app is actually running
    guard targetApp.isFinishedLaunching else {
      throw AltSwitchError.appNotFound(bundleID: app.bundleIdentifier)
    }

    // Unhide the application
    if targetApp.isHidden {
      targetApp.unhide()
    }

    // Verify the operation succeeded by checking the hidden state
    // Note: There's a slight delay for the state to update
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

    // Re-check if still hidden (operation may have failed)
    if targetApp.isHidden {
      throw AltSwitchError.appDiscoveryFailed(
        underlying: NSError(
          domain: "AppSwitcher",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: "Failed to unhide application"]
        )
      )
    }
  }
}
