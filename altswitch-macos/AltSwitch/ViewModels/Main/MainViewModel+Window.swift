import AppKit
import SwiftUI

@MainActor
extension MainViewModel {
  func setWindow(_ window: NSWindow) {
    self.window = window
    configureWindowIfNeeded(window)
  }

  func show() {
    print("🪟 [show] START - allApps.count: \(allApps.count), filteredApps.count: \(filteredApps.count)")
    // Check permissions FIRST before doing any expensive work
    checkAccessibilityPermission()

    // If permissions not granted, show alert and don't proceed
    if !hasAccessibilityPermission {
      print("⚠️ [show] No accessibility permission")
      showPermissionAlert()
      return
    }

    if window == nil {
      AppDelegate.shared?.setupMainWindow()
    }

    guard let window = window ?? NSApp.windows.first(where: { $0.identifier?.rawValue == "main" })
    else {
      print("❌ [show] No window found")
      return
    }

    // Order out the window initially to prevent flash
    window.orderOut(nil)

    // Position the window BEFORE making it visible to prevent left-side flash
    if let screen = configuration.restrictToMainDisplay
      ? NSScreen.menuBarScreen
      : window.screen ?? NSScreen.main
    {
      window.move(to: screen, centered: true, animate: false)
    }

    // CRITICAL: Refresh data FIRST to get fresh allApps, THEN clear search state
    Task { @MainActor in
      print("🔄 [show] Refreshing apps FIRST...")
      await refreshApps()
      print("✅ [show] Refresh complete - allApps: \(allApps.count), filteredApps: \(filteredApps.count)")

      // WARMUP: Do a follow-up refresh to pick up titles discovered in the background
      // This happens asynchronously and doesn't delay the UI
      Task { @MainActor in
        // Wait for MacWindowDiscovery's title cache to populate
        try? await Task.sleep(nanoseconds: 250_000_000) // 250ms
        print("🔥 [show] Warmup refresh - re-caching with discovered titles...")
        await refreshApps()
        print("✅ [show] Warmup complete - allApps: \(allApps.count), filteredApps: \(filteredApps.count)")
      }

      print("🎬 [show] Now clearing search state with fresh data")
      // Clear search and selection AFTER refresh so updateFilteredApps() uses fresh allApps
      searchText = ""
      selectedIndex = 0
      print("🧹 [show] Search cleared - filteredApps: \(filteredApps.count)")

      configureWindowIfNeeded(window)

      print("🪟 [show] Setting isVisible=true")
      // Set state to trigger SwiftUI layout
      isVisible = true
      print("📊 [show] After isVisible=true - allApps: \(allApps.count), filteredApps: \(filteredApps.count)")

      // Capture current frame to detect when SwiftUI updates it
      let currentFrame = window.frame
      print("📐 [show] Current frame height: \(currentFrame.height)")

      // Observe frame changes and show window once SwiftUI layout completes
      var frameObserver: NSKeyValueObservation?
      var hasShown = false

      frameObserver = window.observe(\.frame, options: [.new]) { [weak self] observedWindow, change in
        guard let self = self, let newFrame = change.newValue, !hasShown else { return }

        // Check if frame has changed from the initial value (SwiftUI has updated layout)
        if newFrame.height != currentFrame.height && newFrame.height > 0 {
          print("✅ [show] Frame updated from \(currentFrame.height) to \(newFrame.height), showing window")
          hasShown = true

          // Remove observer immediately
          frameObserver?.invalidate()
          frameObserver = nil

          // Now make the window visible
          AppActivation.activate()
          observedWindow.makeKeyAndOrderFront(nil)
          // Note: Don't call makeFirstResponder here - let SwiftUI's @FocusState manage focus
          // The MainWindow view sets isSearchFocused = true in .onChange(of: viewModel.isVisible)
        }
      }

      // Fallback: If frame doesn't change within a reasonable time, show anyway
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        if !hasShown {
          print("⚠️ [show] Fallback timeout reached, showing window")
          hasShown = true
          frameObserver?.invalidate()
          frameObserver = nil

          AppActivation.activate()
          window.makeKeyAndOrderFront(nil)
        }
      }
    }
  }

  private func showPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = """
      AltSwitch requires Accessibility permissions to function.

      Please grant permissions in:
      System Settings → Privacy & Security → Accessibility

      Then restart AltSwitch.
      """
    alert.alertStyle = .warning
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Cancel")

    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      // Open System Settings to Accessibility pane
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
      {
        NSWorkspace.shared.open(url)
      }
    }
  }

  func hide() {
    print("🙈 [hide] START - allApps: \(allApps.count), filteredApps: \(filteredApps.count)")
    isVisible = false
    searchText = ""
    selectedIndex = 0
    print("🙈 [hide] After clearing state - allApps: \(allApps.count), filteredApps: \(filteredApps.count)")

    if let window = window ?? NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
      window.orderOut(nil)
    }
  }

  func toggleVisibility() {
    if isVisible {
      if !NSApp.isActive {
        hide()
        return
      }

      if let window = window, !window.isKeyWindow {
        hide()
        return
      }

      hide()
    } else {
      show()
    }
  }

  func configureWindowIfNeeded(_ window: NSWindow) {
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.isOpaque = false
    window.backgroundColor = .clear
  }
}
