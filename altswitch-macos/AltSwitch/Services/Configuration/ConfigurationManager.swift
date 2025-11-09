//
//  ConfigurationManager.swift
//  AltSwitch
//
//  Legacy configuration manager for backward compatibility
//  New implementations should use SettingsManager directly
//

import Foundation
import Observation

/// Legacy configuration manager - wraps SettingsManager for backward compatibility
@MainActor
@Observable
final class ConfigurationManager {

  // MARK: - Dependencies

  private let settingsManager: SettingsManagerProtocol

  // MARK: - Observable Properties

  /// Current configuration (reactive)
  var configuration: Configuration {
    get { settingsManager.currentConfiguration }
    set {
      Task {
        do {
          try await settingsManager.saveConfiguration(newValue)
        } catch {
          print("Failed to save configuration: \(error)")
        }
      }
    }
  }

  // MARK: - Initialization

  /// Initialize with a settings manager
  init(settingsManager: SettingsManagerProtocol) {
    self.settingsManager = settingsManager
  }

  /// Legacy initializer for backward compatibility
  init() {
    do {
      self.settingsManager = try SettingsManager()
    } catch {
      // Fallback to temporary settings manager
      print("Warning: Failed to create settings manager: \(error)")
      let tempURL = URL(fileURLWithPath: "/tmp/altswitch_fallback_config.yaml")
      do {
        self.settingsManager = try SettingsManager(configurationFileURL: tempURL)
      } catch {
        fatalError("Unable to initialize fallback SettingsManager: \(error)")
      }
    }
  }

  // MARK: - Modern Interface

  /// Save the current configuration (async)
  func save() async throws {
    try await settingsManager.saveConfiguration(configuration)
  }

  /// Load configuration from storage (async)
  func load() async throws {
    _ = try await settingsManager.loadConfiguration()
    // Configuration will automatically update via the reactive property
  }

  /// Access to underlying settings manager
  var underlyingSettingsManager: SettingsManagerProtocol {
    return settingsManager
  }
}
