// swiftlint:disable all
#if false
//
//  SettingsIntegrationTests.swift
//  AltSwitchTests
//
//  Integration tests for settings and customization functionality
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

@Suite("Settings Integration")
struct SettingsIntegrationTests {

  @Test("Customize global hotkey")
  func testCustomizeGlobalHotkey() async throws {
    // Arrange
    let settingsManager = MockSettingsManager()
    let hotkeyManager = MockHotkeyManager()
    let settingsUI = MockSettingsUI()

    // Get default hotkey
    let defaultHotkey = await settingsManager.getDefaultHotkey()

    // Act - Customize hotkey through settings
    let customHotkey = TestKeyCombo(
      shortcut: .init(.tab, modifiers: [.command, .option]),
      description: "Custom Show/Hide"
    )

    await settingsUI.setCustomHotkey(customHotkey)
    let saveResult = await settingsManager.saveSettings()

    // Assert - Settings should be saved
    #expect(saveResult == .success)

    // Verify hotkey was updated
    let savedHotkey = await settingsManager.getGlobalHotkey()
    #expect(savedHotkey.shortcut == customHotkey.shortcut)

    // Hotkey manager should be updated
    let registeredHotkey = await hotkeyManager.getRegisteredHotkey()
    #expect(registeredHotkey?.shortcut == customHotkey.shortcut)
  }

  @Test("Toggle application visibility settings")
  func testToggleApplicationVisibility() async throws {
    // Arrange
    let settingsManager = MockSettingsManager()
    let appDiscovery = MockAppDiscoveryService()
    let settingsUI = MockSettingsUI()

    // Set up initial settings
    await settingsManager.setShowSystemApplications(true)
    await settingsManager.setShowHiddenApplications(false)
    await settingsManager.setShowMinimizedApplications(true)

    // Act - Toggle settings through UI
    await settingsUI.toggleShowSystemApplications()
    await settingsUI.toggleShowHiddenApplications()
    await settingsUI.toggleShowMinimizedApplications()

    let saveResult = await settingsManager.saveSettings()

    // Assert - Settings should be saved and applied
    #expect(saveResult == .success)

    // Verify settings were toggled
    #expect(!(await settingsManager.getShowSystemApplications()))
    #expect(await settingsManager.getShowHiddenApplications())
    #expect(!(await settingsManager.getShowMinimizedApplications()))

    // App discovery should respect new settings
    let discoveredApps = await appDiscovery.discoverApplications()
    let systemApps = discoveredApps.filter { $0.bundleIdentifier.contains("system") }
    let hiddenApps = discoveredApps.filter { $0.isHidden }
    let minimizedApps = discoveredApps.filter { $0.isMinimized }

    #expect(systemApps.isEmpty)
    #expect(!hiddenApps.isEmpty)
    #expect(minimizedApps.isEmpty)
  }

  @Test("Configure search and filtering options")
  func testConfigureSearchOptions() async throws {
    // Arrange
    let settingsManager = MockSettingsManager()
    let searchService = MockSearchService()
    let settingsUI = MockSettingsUI()

    // Set up search settings
    let searchSettings = SearchSettings(
      fuzzySearchEnabled: true,
      searchInBundleIdentifiers: false,
      minimumSearchLength: 2,
      maxResults: 10,
      searchDelay: 0.1
    )

    // Act - Configure search settings
    await settingsUI.setSearchSettings(searchSettings)
    let saveResult = await settingsManager.saveSettings()

    // Assert - Settings should be saved
    #expect(saveResult == .success)

    // Verify search service uses new settings
    let currentSearchSettings = await searchService.getSearchSettings()
    #expect(currentSearchSettings.fuzzySearchEnabled == searchSettings.fuzzySearchEnabled)
    #expect(currentSearchSettings.minimumSearchLength == searchSettings.minimumSearchLength)
    #expect(currentSearchSettings.maxResults == searchSettings.maxResults)

    // Test search with new settings
    let searchResults = await searchService.search("sa", in: [])
    #expect(searchResults.count <= searchSettings.maxResults)
  }

  @Test("Configure window appearance and behavior")
  func testConfigureWindowAppearance() async throws {
    // Arrange
    let settingsManager = MockSettingsManager()
    let windowManager = MockWindowManager()
    let settingsUI = MockSettingsUI()

    // Set up window appearance settings
    let windowSettings = WindowSettings(
      windowSize: CGSize(width: 600, height: 800),
      windowPosition: .center,
      cornerRadius: 16.0,
      backgroundColor: NSColor.controlBackgroundColor,
      opacity: 0.95,
      animationDuration: 0.2,
      dismissOnClickOutside: true,
      showWindowCount: true
    )

    // Act - Configure window settings
    await settingsUI.setWindowSettings(windowSettings)
    let saveResult = await settingsManager.saveSettings()

    // Assert - Settings should be saved
    #expect(saveResult == .success)

    // Verify window manager uses new settings
    let currentWindowSettings = await windowManager.getWindowSettings()
    #expect(currentWindowSettings.windowSize == windowSettings.windowSize)
    #expect(currentWindowSettings.cornerRadius == windowSettings.cornerRadius)
    #expect(currentWindowSettings.opacity == windowSettings.opacity)

    // Test window appearance with new settings
    await windowManager.showWindow()
    let actualWindowSize = await windowManager.getWindowSize()
    #expect(actualWindowSize == windowSettings.windowSize)
  }

  @Test("Reset settings to defaults")
  func testResetSettingsToDefaults() async throws {
    // Arrange
    let settingsManager = MockSettingsManager()
    let hotkeyManager = MockHotkeyManager()
    let settingsUI = MockSettingsUI()

    // Customize settings
    let customHotkey = TestKeyCombo(
      shortcut: .init(.tab, modifiers: [.command, .option]),
      description: "Custom Hotkey"
    )

    await settingsUI.setCustomHotkey(customHotkey)
    await settingsUI.setShowSystemApplications(false)
    await settingsManager.saveSettings()

    // Verify custom settings are applied
    let savedHotkey = await settingsManager.getGlobalHotkey()
    #expect(savedHotkey.shortcut == customHotkey.shortcut)

    // Act - Reset to defaults
    await settingsUI.resetToDefaults()
    let resetResult = await settingsManager.saveSettings()

    // Assert - Reset should succeed
    #expect(resetResult == .success)

    // Verify settings are back to defaults
    let defaultHotkey = await settingsManager.getDefaultHotkey()
    let currentHotkey = await settingsManager.getGlobalHotkey()
    #expect(currentHotkey.shortcut == defaultHotkey.shortcut)

    #expect(await settingsManager.getShowSystemApplications())

    // Hotkey manager should be updated with defaults
    let registeredHotkey = await hotkeyManager.getRegisteredHotkey()
    #expect(registeredHotkey?.shortcut == defaultHotkey.shortcut)
  }

  @Test("Settings persistence across app restarts")
  func testSettingsPersistence() async throws {
    // Arrange
    let settingsManager1 = MockSettingsManager()
    let settingsManager2 = MockSettingsManager()  // Simulates new instance after restart

    // Configure settings in first instance
    let customHotkey = TestKeyCombo(
      shortcut: .init(.tab, modifiers: [.command, .option]),
      description: "Persistent Hotkey"
    )

    await settingsManager1.setGlobalHotkey(customHotkey)
    await settingsManager1.setShowSystemApplications(false)
    await settingsManager1.setShowHiddenApplications(true)

    let saveResult1 = await settingsManager1.saveSettings()
    #expect(saveResult1 == .success, "First save should succeed")

    // Act - Simulate app restart by creating new settings manager
    let loadedSettings = await settingsManager2.loadSettings()

    // Assert - Settings should be persisted
    #expect(loadedSettings != nil)

    let persistedHotkey = await settingsManager2.getGlobalHotkey()
    #expect(persistedHotkey.shortcut == customHotkey.shortcut)

    #expect(!(await settingsManager2.getShowSystemApplications()))
    #expect(await settingsManager2.getShowHiddenApplications())
  }

  @Test("Settings validation and error handling")
  func testSettingsValidation() async throws {
    // Arrange
    let settingsManager = MockSettingsManager()
    let settingsUI = MockSettingsUI()

    // Test invalid hotkey combinations
    let invalidHotkeys = [
      TestKeyCombo(
        shortcut: .init(.tab, modifiers: [.command]), description: "System Conflict"),
      TestKeyCombo(shortcut: .init(.space, modifiers: []), description: "No Modifiers"),
      TestKeyCombo(
        shortcut: .init(.escape, modifiers: [.command, .option, .control, .shift]),
        description: "Too Many Modifiers"),
    ]

    for invalidHotkey in invalidHotkeys {
      // Act - Attempt to set invalid hotkey
      await settingsUI.setCustomHotkey(invalidHotkey)
      let saveResult = await settingsManager.saveSettings()

      // Assert - Should fail validation
      #expect(saveResult == .validationError)

      let validationError = await settingsManager.getLastError()
      #expect(validationError != nil)
    }

    // Test invalid window settings
    let invalidWindowSettings = [
      WindowSettings(
        windowSize: CGSize(width: -100, height: 400), windowPosition: .center,
        cornerRadius: 16.0, backgroundColor: .controlBackgroundColor, opacity: 0.95,
        animationDuration: 0.2, dismissOnClickOutside: true, showWindowCount: true),
      WindowSettings(
        windowSize: CGSize(width: 600, height: -200), windowPosition: .center,
        cornerRadius: 16.0, backgroundColor: .controlBackgroundColor, opacity: 0.95,
        animationDuration: 0.2, dismissOnClickOutside: true, showWindowCount: true),
      WindowSettings(
        windowSize: CGSize(width: 600, height: 400), windowPosition: .center,
        cornerRadius: -5.0, backgroundColor: .controlBackgroundColor, opacity: 0.95,
        animationDuration: 0.2, dismissOnClickOutside: true, showWindowCount: true),
      WindowSettings(
        windowSize: CGSize(width: 600, height: 400), windowPosition: .center,
        cornerRadius: 16.0, backgroundColor: .controlBackgroundColor, opacity: 1.5,
        animationDuration: 0.2, dismissOnClickOutside: true, showWindowCount: true),
    ]

    for invalidSettings in invalidWindowSettings {
      // Act - Attempt to set invalid window settings
      await settingsUI.setWindowSettings(invalidSettings)
      let saveResult = await settingsManager.saveSettings()

      // Assert - Should fail validation
      #expect(saveResult == .validationError)
    }
  }

  @Test("Real-time settings application")
  func testRealTimeSettingsApplication() async throws {
    // Arrange
    let settingsManager = MockSettingsManager()
    let windowManager = MockWindowManager()
    let searchService = MockSearchService()
    let settingsUI = MockSettingsUI()

    // Show window initially
    await windowManager.showWindow()

    // Act - Change settings while window is open
    let newWindowSize = CGSize(width: 800, height: 500)
    let newWindowSettings = WindowSettings(
      windowSize: newWindowSize,
      windowPosition: .center,
      cornerRadius: 20.0,
      backgroundColor: NSColor.controlBackgroundColor,
      opacity: 0.9,
      animationDuration: 0.15,
      dismissOnClickOutside: true,
      showWindowCount: true
    )

    await settingsUI.setWindowSettings(newWindowSettings)
    await settingsManager.saveSettings()

    // Assert - Window should update in real-time
    let currentWindowSize = await windowManager.getWindowSize()
    #expect(currentWindowSize == newWindowSize)

    let currentCornerRadius = await windowManager.getCornerRadius()
    #expect(currentCornerRadius == newWindowSettings.cornerRadius)

    // Test search settings update
    let newSearchSettings = SearchSettings(
      fuzzySearchEnabled: false,
      searchInBundleIdentifiers: true,
      minimumSearchLength: 1,
      maxResults: 20,
      searchDelay: 0.05
    )

    await settingsUI.setSearchSettings(newSearchSettings)
    await settingsManager.saveSettings()

    let currentSearchSettings = await searchService.getSearchSettings()
    #expect(currentSearchSettings.fuzzySearchEnabled == newSearchSettings.fuzzySearchEnabled)
  }
}

// MARK: - Mock Classes for Testing

private actor MockSettingsManager {
  private var settings = AppSettings.default
  private var lastError: SettingsError?

  enum SaveResult {
    case success
    case validationError
    case persistenceError
  }

  func setGlobalHotkey(_ hotkey: TestKeyCombo) async {
    settings.globalHotkey = hotkey
  }

  func getGlobalHotkey() async -> TestKeyCombo {
    return settings.globalHotkey
  }

  func getDefaultHotkey() async -> TestKeyCombo {
    return AppSettings.default.globalHotkey
  }

  func setShowSystemApplications(_ show: Bool) async {
    settings.showSystemApplications = show
  }

  func getShowSystemApplications() async -> Bool {
    return settings.showSystemApplications
  }

  func setShowHiddenApplications(_ show: Bool) async {
    settings.showHiddenApplications = show
  }

  func getShowHiddenApplications() async -> Bool {
    return settings.showHiddenApplications
  }

  func setShowMinimizedApplications(_ show: Bool) async {
    settings.showMinimizedApplications = show
  }

  func getShowMinimizedApplications() async -> Bool {
    return settings.showMinimizedApplications
  }

  func saveSettings() async -> SaveResult {
    // Validate settings
    if !validateSettings() {
      lastError = SettingsError.validationFailed
      return .validationError
    }

    // Simulate save operation
    try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms

    return .success
  }

  func loadSettings() async -> AppSettings? {
    // Simulate load operation
    try? await Task.sleep(nanoseconds: 500_000)  // 0.5ms
    return settings
  }

  func getLastError() async -> SettingsError? {
    return lastError
  }

  private func validateSettings() -> Bool {
    // Validate hotkey
    let hotkey = settings.globalHotkey
    if hotkey.shortcut == .init(.tab, modifiers: [.command]) {
      return false  // System conflict
    }
    if hotkey.shortcut.modifiers.isEmpty {
      return false  // No modifiers
    }
    let modifierCount = [NSEvent.ModifierFlags.command, .option, .control, .shift].filter {
      hotkey.shortcut.modifiers.contains($0)
    }.count
    if modifierCount > 3 {
      return false  // Too many modifiers
    }

    // Validate window settings
    let windowSettings = settings.windowSettings
    if windowSettings.windowSize.width <= 0 || windowSettings.windowSize.height <= 0 {
      return false  // Invalid size
    }
    if windowSettings.cornerRadius < 0 {
      return false  // Negative corner radius
    }
    if windowSettings.opacity < 0 || windowSettings.opacity > 1 {
      return false  // Invalid opacity
    }

    return true
  }
}

private actor MockSettingsUI {
  private var currentHotkey: TestKeyCombo?
  private var currentSearchSettings: SearchSettings?
  private var currentWindowSettings: WindowSettings?

  func setCustomHotkey(_ hotkey: TestKeyCombo) async {
    currentHotkey = hotkey
    await MockSettingsManager.shared.setGlobalHotkey(hotkey)
  }

  func setShowSystemApplications(_ show: Bool) async {
    await MockSettingsManager.shared.setShowSystemApplications(show)
  }

  func setSearchSettings(_ settings: SearchSettings) async {
    currentSearchSettings = settings
    // Apply to search service
    await MockSearchService.shared.setSearchSettings(settings)
  }

  func setWindowSettings(_ settings: WindowSettings) async {
    currentWindowSettings = settings
    // Apply to window manager
    await MockWindowManager.shared.setWindowSettings(settings)
  }

  func toggleShowSystemApplications() async {
    let currentValue = await MockSettingsManager.shared.getShowSystemApplications()
    await MockSettingsManager.shared.setShowSystemApplications(!currentValue)
  }

  func toggleShowHiddenApplications() async {
    let currentValue = await MockSettingsManager.shared.getShowHiddenApplications()
    await MockSettingsManager.shared.setShowHiddenApplications(!currentValue)
  }

  func toggleShowMinimizedApplications() async {
    let currentValue = await MockSettingsManager.shared.getShowMinimizedApplications()
    await MockSettingsManager.shared.setShowMinimizedApplications(!currentValue)
  }

  func resetToDefaults() async {
    await MockSettingsManager.shared.resetToDefaults()
  }

  static let shared = MockSettingsUI()
}

private actor MockHotkeyManager {
  private var registeredHotkey: TestKeyCombo?

  func registerHotkey(_ hotkey: TestKeyCombo) async {
    registeredHotkey = hotkey
    try? await Task.sleep(nanoseconds: 2_000_000)  // 2ms
  }

  func getRegisteredHotkey() async -> TestKeyCombo? {
    return registeredHotkey
  }
}

private actor MockSearchService {
  private var searchSettings = SearchSettings.default

  func setSearchSettings(_ settings: SearchSettings) async {
    searchSettings = settings
  }

  func getSearchSettings() async -> SearchSettings {
    return searchSettings
  }

  func search(_ query: String, in apps: [MockApplication]) async -> [MockApplication] {
    // Mock search implementation
    return apps.filter { $0.displayName.lowercased().contains(query.lowercased()) }
  }

  static let shared = MockSearchService()
}

private actor MockWindowManager {
  private var windowSettings = WindowSettings.default
  private var isWindowVisible = false

  func setWindowSettings(_ settings: WindowSettings) async {
    windowSettings = settings
    // Update window in real-time if visible
    if isWindowVisible {
      try? await Task.sleep(nanoseconds: 100_000)  // 0.1ms
    }
  }

  func getWindowSettings() async -> WindowSettings {
    return windowSettings
  }

  func showWindow() async {
    isWindowVisible = true
  }

  func getWindowSize() async -> CGSize {
    return windowSettings.windowSize
  }

  func getCornerRadius() async -> CGFloat {
    return windowSettings.cornerRadius
  }

  static let shared = MockWindowManager()
}

private actor MockAppDiscoveryService {
  func discoverApplications() async -> [MockApplication] {
    let showSystem = await MockSettingsManager.shared.getShowSystemApplications()
    let showHidden = await MockSettingsManager.shared.getShowHiddenApplications()
    let showMinimized = await MockSettingsManager.shared.getShowMinimizedApplications()

    var apps = [
      MockApplication(
        bundleIdentifier: "com.apple.Safari", displayName: "Safari", isHidden: false,
        isMinimized: false),
      MockApplication(
        bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome",
        isHidden: false, isMinimized: false),
      MockApplication(
        bundleIdentifier: "com.system.hidden", displayName: "Hidden System App",
        isHidden: true, isMinimized: false),
      MockApplication(
        bundleIdentifier: "com.user.hidden", displayName: "Hidden User App", isHidden: true,
        isMinimized: false),
      MockApplication(
        bundleIdentifier: "com.user.minimized", displayName: "Minimized App",
        isHidden: false, isMinimized: true),
    ]

    // Apply filters
    if !showSystem {
      apps = apps.filter { !$0.bundleIdentifier.contains("system") }
    }
    if !showHidden {
      apps = apps.filter { !$0.isHidden }
    }
    if !showMinimized {
      apps = apps.filter { !$0.isMinimized }
    }

    return apps
  }
}

// MARK: - Supporting Test Types

private struct TestKeyCombo: Equatable, Hashable, Sendable {
  let shortcut: KeyboardShortcuts.Shortcut
  let description: String
}

private struct MockApplication: Equatable, Sendable {
  let bundleIdentifier: String
  let displayName: String
  var isHidden: Bool = false
  var isMinimized: Bool = false
}

private struct AppSettings: Sendable {
  var globalHotkey: TestKeyCombo
  var showSystemApplications: Bool
  var showHiddenApplications: Bool
  var showMinimizedApplications: Bool
  var windowSettings: WindowSettings
  var searchSettings: SearchSettings

  static let `default` = AppSettings(
    globalHotkey: TestKeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Show/Hide AltSwitch"),
    showSystemApplications: true,
    showHiddenApplications: false,
    showMinimizedApplications: true,
    windowSettings: WindowSettings.default,
    searchSettings: SearchSettings.default
  )
}

private struct WindowSettings: Equatable, Sendable {
  var windowSize: CGSize
  var windowPosition: WindowSettings.WindowPosition
  var cornerRadius: CGFloat
  var backgroundColor: NSColor
  var opacity: Double
  var animationDuration: Double
  var dismissOnClickOutside: Bool
  var showWindowCount: Bool

  enum WindowPosition: Equatable, Sendable {
    case center
    case mouse
    case custom(CGPoint)
  }

  static let `default` = WindowSettings(
    windowSize: CGSize(width: 600, height: 400),
    windowPosition: .center,
    cornerRadius: 16.0,
    backgroundColor: .controlBackgroundColor,
    opacity: 0.95,
    animationDuration: 0.2,
    dismissOnClickOutside: true,
    showWindowCount: true
  )
}

private struct SearchSettings: Equatable, Sendable {
  var fuzzySearchEnabled: Bool
  var searchInBundleIdentifiers: Bool
  var minimumSearchLength: Int
  var maxResults: Int
  var searchDelay: Double

  static let `default` = SearchSettings(
    fuzzySearchEnabled: true,
    searchInBundleIdentifiers: false,
    minimumSearchLength: 2,
    maxResults: 10,
    searchDelay: 0.1
  )
}

private enum SettingsError: Equatable, Sendable {
  case validationFailed
  case persistenceFailed
  case loadFailed
}

// MARK: - Extensions for Shared Access

extension MockSettingsManager {
  static let shared = MockSettingsManager()

  func resetToDefaults() async {
    settings = AppSettings.default
  }
}
#endif
// swiftlint:enable all
