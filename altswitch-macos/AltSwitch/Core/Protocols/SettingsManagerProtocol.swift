//
//  SettingsManagerProtocol.swift
//  AltSwitch
//
//  Protocol for managing application settings with reactive updates
//

import Foundation

/// Protocol for managing application settings with YAML persistence and change notifications
protocol SettingsManagerProtocol: Sendable {
  /// Current configuration (reactive access)
  var currentConfiguration: Configuration { get }

  // MARK: - Configuration Management

  /// Load configuration from storage
  /// - Returns: The loaded configuration
  /// - Throws: SettingsError if loading fails
  func loadConfiguration() async throws -> Configuration

  /// Save configuration to storage
  /// - Parameter config: The configuration to save
  /// - Throws: SettingsError if saving fails
  func saveConfiguration(_ config: Configuration) async throws

  /// Reset configuration to factory defaults
  /// - Returns: The default configuration that was applied
  func resetToDefaults() async -> Configuration

  // MARK: - Change Notifications

  /// Register for configuration change notifications
  /// - Parameter handler: The handler to call when configuration changes
  func onConfigurationChanged(_ handler: @escaping @Sendable (Configuration) -> Void)
}

/// Errors that can occur during settings operations
enum SettingsError: Error, Equatable, Sendable {
  case fileNotFound
  case invalidFormat(String)
  case permissionDenied
  case diskFull
  case corruptedData
  case migrationFailed(String)
  case validationFailed(String)
}

/// Extension for convenience methods
extension SettingsManagerProtocol {
  /// Update a specific hotkey in the configuration
  /// - Parameters:
  ///   - hotkey: The hotkey type to update
  ///   - combo: The new key combination
  /// - Throws: SettingsError if saving fails
  func updateHotkey(_ hotkey: HotkeyType, to combo: KeyCombo) async throws {
    let config = currentConfiguration.copy()
    switch hotkey {
    case .showHide:
      config.showHotkey = combo
    case .settings, .refresh:
      // For now, only showHide hotkey is supported in Configuration
      // Additional hotkeys would require expanding the Configuration model
      config.showHotkey = combo
    }
    try await saveConfiguration(config)
  }

  /// Toggle fuzzy search setting
  /// - Throws: SettingsError if saving fails
  func toggleFuzzySearch() async throws {
    let config = currentConfiguration.copy()
    config.enableFuzzySearch.toggle()
    try await saveConfiguration(config)
  }

  /// Toggle window counts setting
  /// - Throws: SettingsError if saving fails
  func toggleWindowCounts() async throws {
    let config = currentConfiguration.copy()
    config.showWindowCounts.toggle()
    try await saveConfiguration(config)
  }

  /// Toggle sounds setting
  /// - Throws: SettingsError if saving fails
  func toggleSounds() async throws {
    let config = currentConfiguration.copy()
    config.enableSounds.toggle()
    try await saveConfiguration(config)
  }

  /// Update hotkey initialization delay
  /// - Parameter delay: The new delay in seconds (0-0.1)
  /// - Throws: SettingsError if saving fails
  func updateHotkeyInitDelay(_ delay: TimeInterval) async throws {
    let config = currentConfiguration.copy()
    config.hotkeyInitDelay = delay
    try await saveConfiguration(config)
  }
}

/// Hotkey types for configuration management
enum HotkeyType: String, CaseIterable, Sendable {
  case showHide = "showHide"
  case settings = "settings"
  case refresh = "refresh"

  var displayName: String {
    switch self {
    case .showHide: return "Show/Hide AltSwitch"
    case .settings: return "Open Settings"
    case .refresh: return "Refresh App List"
    }
  }

  var defaultKeyCombo: KeyCombo {
    switch self {
    case .showHide: return .defaultShowHide()
    case .settings: return .defaultSettings()
    case .refresh: return .defaultRefresh()
    }
  }
}
