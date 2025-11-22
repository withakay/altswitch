//
//  MainViewModel.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import AppKit
import Carbon
import CoreGraphics
import Foundation
import Observation
import SwiftUI

/// Main view model for coordinating app discovery, search, and window management
@MainActor
@Observable
final class MainViewModel {
  // MARK: - Observable Properties

  /// Whether the switcher window is currently visible
  var isVisible = false

  /// Current search text
  var searchText = "" {
    didSet {
      print("🔤 [searchText] Changed from '\(oldValue)' to '\(searchText)' - calling updateFilteredApps()")
      updateFilteredApps()
    }
  }

  /// All discovered applications
  private(set) var allApps: [AppInfo] = []

  /// Filtered applications based on search
  internal(set) var filteredApps: [SearchResult] = []

  /// Currently selected index in filtered results
  private var _selectedIndex = 0
  var selectedIndex: Int {
    get { _selectedIndex }
    set {
      if !filteredApps.isEmpty {
        _selectedIndex = max(0, min(newValue, filteredApps.count - 1))
      } else {
        _selectedIndex = 0
      }
    }
  }

  /// Loading state for app discovery
  private(set) var isLoading = false

  /// Any error that occurred
  internal(set) var lastError: Error?

  /// Whether accessibility permissions are granted
  private(set) var hasAccessibilityPermission = false

  // MARK: - Dependencies

  let appDiscovery: AppDiscoveryProtocol
  private let appSwitcher: AppSwitcherProtocol
  let fuzzySearch: FuzzySearchProtocol
  let hotkeyManager: HotkeyManagerProtocol
  let settingsManager: SettingsManagerProtocol
  let activationTracker: AppActivationTracker

  // MARK: - Private Properties

  nonisolated(unsafe) private var refreshTask: Task<Void, Never>?
  nonisolated(unsafe) var debounceTask: Task<Void, Never>?
  var selectionShortcutMonitors: [Any] = []
  weak var window: NSWindow?

  /// Current configuration from settings manager
  internal(set) var configuration: Configuration

  // MARK: - Initialization

  init(
    appDiscovery: AppDiscoveryProtocol = PackageAppDiscovery(),
    appSwitcher: AppSwitcherProtocol = AppSwitcher.shared,
    fuzzySearch: FuzzySearchProtocol = FuzzySearchService(),
    hotkeyManager: HotkeyManagerProtocol = KeyboardShortcutsHotkeyManager(),
    settingsManager: SettingsManagerProtocol? = nil,
    activationTracker: AppActivationTracker = AppActivationTracker()
  ) {
    self.appDiscovery = appDiscovery
    self.appSwitcher = appSwitcher
    self.fuzzySearch = fuzzySearch
    self.hotkeyManager = hotkeyManager
    self.activationTracker = activationTracker

    // Initialize settings manager with error handling
    if let settingsManager = settingsManager {
      self.settingsManager = settingsManager
    } else {
      do {
        self.settingsManager = try SettingsManager()
      } catch {
        print("Failed to initialize settings manager: \(error)")
        let tempURL = URL(fileURLWithPath: "/tmp/altswitch_settings.yaml")
        do {
          self.settingsManager = try SettingsManager(configurationFileURL: tempURL)
        } catch {
          fatalError("Unable to initialize SettingsManager even with fallback: \(error)")
        }
      }
    }

    // Get current configuration
    self.configuration = self.settingsManager.currentConfiguration

    // Apply initial filter configuration to PackageAppDiscovery
    if let packageDiscovery = appDiscovery as? PackageAppDiscovery {
      packageDiscovery.applicationNameExcludeList = self.configuration.applicationNameExcludeList
      packageDiscovery.untitledWindowExcludeList = self.configuration.untitledWindowExcludeList
    }

    Task {
      // Check permissions FIRST before doing any expensive work
      checkAccessibilityPermission()

      // CRITICAL: Setup cache subscription BEFORE starting discovery
      // This ensures we receive notifications even if permissions aren't granted yet
      setupCacheSubscription()

      // Start app discovery regardless of permissions
      // WindowCache will work with limited functionality without accessibility access
      await startAppDiscovery()

      setupSelectionShortcuts()
      setupConfigurationObserver()

      // Wait a short time for configuration to load from YAML, then refresh if needed
      try? await Task.sleep(for: .milliseconds(100))

      // Get the potentially updated configuration after YAML loading
      await MainActor.run {
        self.configuration = self.settingsManager.currentConfiguration
        
        // Update PackageAppDiscovery filters after YAML load
        if let packageDiscovery = self.appDiscovery as? PackageAppDiscovery {
          packageDiscovery.applicationNameExcludeList = self.configuration.applicationNameExcludeList
          packageDiscovery.untitledWindowExcludeList = self.configuration.untitledWindowExcludeList
        }
      }
      
      // Refresh apps to apply filters from YAML
      await refreshApps()
    }
  }

  deinit {
    refreshTask?.cancel()
    debounceTask?.cancel()
  }

  /// Check and update accessibility permission status
  func checkAccessibilityPermission() {
    let permissionManager = AccessibilityPermissionManager.shared
    permissionManager.checkStatus()
    hasAccessibilityPermission = permissionManager.isGranted
  }

  // MARK: - Public Methods

  /// Switch to the selected application
  func switchToSelectedApp() async {
    guard selectedIndex < filteredApps.count else { return }

    let selectedResult = filteredApps[selectedIndex]

    do {
      // Hide our window first
      hide()

      // Switch to the selected app
      try await appSwitcher.switchTo(selectedResult.app)

      // Record this activation for ordering
      activationTracker.recordActivation(for: selectedResult.app.bundleIdentifier)
    } catch AltSwitchError.accessibilityPermissionDenied {
      lastError = AltSwitchError.accessibilityPermissionDenied
      print("Accessibility permission denied - app switching may be limited")
    } catch {
      lastError = error
      print("Failed to switch to app: \(error)")
    }
  }

  /// Switch to app at specific index (for Cmd+1-9 shortcuts)
  func switchToApp(at index: Int) async {
    guard index < filteredApps.count else { return }
    selectedIndex = index
    await switchToSelectedApp()
  }

  /// Refresh the list of running applications
  func refreshApps() async {
    print("🔄 [refreshApps] START - isLoading: \(isLoading)")
    guard !isLoading else {
      print("⚠️ [refreshApps] SKIPPED - already loading")
      return
    }

    isLoading = true
    lastError = nil

    do {
      print("📡 [refreshApps] Fetching apps from appDiscovery...")
      let apps = try await appDiscovery.fetchRunningApps(
        showIndividualWindows: configuration.showIndividualWindows)
      print("✅ [refreshApps] Fetched \(apps.count) apps")
      allApps = apps.sorted { app1, app2 in
        if app1.isActive != app2.isActive {
          return app1.isActive
        }
        return app1.localizedName < app2.localizedName
      }
      print("📝 [refreshApps] Set allApps to \(allApps.count) apps")
      print("🔍 [refreshApps] Calling updateFilteredApps()...")
      updateFilteredApps()
      print("✅ [refreshApps] COMPLETE - filteredApps.count: \(filteredApps.count)")
    } catch {
      lastError = error
      print("❌ [refreshApps] Failed to fetch apps: \(error)")
    }

    isLoading = false
  }

  // MARK: - Private Methods
  private func startAppDiscovery() async {
    await refreshApps()

    // NOTE: Polling loop disabled - AppDiscoveryService uses event-driven updates (AXObserver + NSWorkspace notifications)
    // The polling loop was causing 2-second UI hitches by running refreshApps() on MainActor
    // Event-driven mode is automatically enabled when Accessibility permissions are granted
    // If you need polling fallback, check AXIsProcessTrusted() first and only poll if false

    // refreshTask = Task(priority: .background) { @MainActor in
    //   while !Task.isCancelled {
    //     try? await Task.sleep(for: .seconds(2))
    //     guard !Task.isCancelled else { break }
    //     await refreshApps()
    //   }
    // }

    // Note: setupCacheSubscription() is now called earlier in init, before startAppDiscovery()
  }

  /// Subscribe to cache changes from AppDiscoveryService
  ///
  /// This replaces the old workspace observer pattern. WindowCache now manages
  /// all workspace observers and notifies us when the cache changes.
  /// This eliminates duplicate observers and race conditions.
  private func setupCacheSubscription() {
    print("[MainViewModel] 📝 Setting up cache subscription")
    appDiscovery.onCacheDidChange { [weak self] in
      print("[MainViewModel] 🔔 Cache changed callback fired!")
      guard let self = self else { return }

      // Cache has been updated - fetch the updated data
      // This is fast because WindowCache.getApps() is synchronous and returns cached data
      Task { @MainActor in
        do {
          print("[MainViewModel] 📥 Fetching updated apps...")
          let apps = try await self.appDiscovery.fetchRunningApps(
            showIndividualWindows: self.configuration.showIndividualWindows)
          print("[MainViewModel] ✅ Fetched \(apps.count) apps")
          self.allApps = apps.sorted { app1, app2 in
            if app1.isActive != app2.isActive {
              return app1.isActive
            }
            return app1.localizedName < app2.localizedName
          }
          self.updateFilteredApps()
          print("[MainViewModel] 🎯 UI updated with \(self.filteredApps.count) filtered apps")
        } catch {
          print("[MainViewModel] ❌ Failed to fetch apps on cache change: \(error)")
        }
      }
    }
  }
}

// MARK: - NSScreen Extension
// Note: displayID and menuBarScreen are now defined in MainDisplayPresenter.swift

// MARK: - Configuration Extensions

extension Configuration {
  /// Extract appearance configuration
  var appearanceConfiguration: AppearanceConfiguration {
    return AppearanceConfiguration(
      maxResults: maxResults,
      windowPosition: windowPosition,
      hotkeyInitDelay: hotkeyInitDelay
    )
  }

  /// Extract behavior configuration
  var behaviorConfiguration: BehaviorConfiguration {
    return BehaviorConfiguration(
      enableFuzzySearch: enableFuzzySearch,
      showWindowCounts: showWindowCounts,
      enableSounds: enableSounds,
      enableAnimations: enableAnimations,
      restrictToMainDisplay: restrictToMainDisplay,
      showIndividualWindows: showIndividualWindows
    )
  }

  /// Update from appearance configuration
  func update(from appearance: AppearanceConfiguration) {
    self.maxResults = appearance.maxResults
    self.windowPosition = appearance.windowPosition
    self.hotkeyInitDelay = appearance.hotkeyInitDelay
  }

  /// Update from behavior configuration
  func update(from behavior: BehaviorConfiguration) {
    self.enableFuzzySearch = behavior.enableFuzzySearch
    self.showWindowCounts = behavior.showWindowCounts
    self.enableSounds = behavior.enableSounds
    self.enableAnimations = behavior.enableAnimations
    self.restrictToMainDisplay = behavior.restrictToMainDisplay
    self.showIndividualWindows = behavior.showIndividualWindows
  }

  /// Update specific hotkey
  func updateHotkey(_ type: HotkeyType, to combo: KeyCombo) {
    switch type {
    case .showHide:
      self.showHideHotkey = combo
    case .settings:
      self.settingsHotkey = combo
    case .refresh:
      self.refreshHotkey = combo
    }
  }
}

/// Appearance configuration subset
struct AppearanceConfiguration: Sendable {
  let maxResults: Int
  let windowPosition: WindowPosition
  let hotkeyInitDelay: TimeInterval
}

/// Behavior configuration subset
struct BehaviorConfiguration: Sendable {
  let enableFuzzySearch: Bool
  let showWindowCounts: Bool
  let enableSounds: Bool
  let enableAnimations: Bool
  let restrictToMainDisplay: Bool
  let showIndividualWindows: Bool
}
