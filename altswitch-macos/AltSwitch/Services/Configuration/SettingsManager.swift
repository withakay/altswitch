//
//  SettingsManager.swift
//  AltSwitch
//
//  YAML-based configuration manager with change notifications and migration support
//  Persists settings to ~/.config/altswitch/settings.yaml
//

import Foundation
import Observation

// MARK: - Implementation

/// YAML-based settings manager with file persistence
final class SettingsManager: SettingsManagerProtocol, Sendable {

  // MARK: - Private Properties

  private let currentConfig = SendableBox<Configuration>(Configuration())
  private let changeHandlers = SendableBox<[@Sendable (Configuration) -> Void]>([])
  private let configDirectoryURL: URL
  private let configFileURL: URL

  // MARK: - Public Properties

  var currentConfiguration: Configuration {
    currentConfig.value
  }

  // MARK: - Initialization

  init() throws {
    // Set up configuration directory path
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    configDirectoryURL =
      homeDirectory
      .appendingPathComponent(".config")
      .appendingPathComponent("altswitch")

    configFileURL = configDirectoryURL.appendingPathComponent("settings.yaml")

    // Create config directory if it doesn't exist
    try Self.createConfigDirectoryIfNeeded(at: configDirectoryURL)

    // Load existing configuration if available
    Task {
      do {
        let loadedConfig = try await loadConfiguration()
        currentConfig.value = loadedConfig
      } catch SettingsError.fileNotFound {
        // File doesn't exist yet, use defaults
        try await saveConfiguration(currentConfig.value)
      } catch {
        // Configuration file exists but is corrupted, back it up and use defaults
        try await backupCorruptedConfiguration()
        try await saveConfiguration(currentConfig.value)
      }
    }
  }

  init(configurationFileURL: URL) throws {
    // Set up configuration directory path from provided URL
    self.configFileURL = configurationFileURL
    self.configDirectoryURL = configurationFileURL.deletingLastPathComponent()

    // Create config directory if it doesn't exist
    try Self.createConfigDirectoryIfNeeded(at: configDirectoryURL)

    // Load existing configuration if available
    Task {
      do {
        let loadedConfig = try await loadConfiguration()
        currentConfig.value = loadedConfig
      } catch SettingsError.fileNotFound {
        // File doesn't exist yet, use defaults
        try await saveConfiguration(currentConfig.value)
      } catch {
        // Configuration file exists but is corrupted, back it up and use defaults
        try await backupCorruptedConfiguration()
        try await saveConfiguration(currentConfig.value)
      }
    }
  }

  // MARK: - SettingsManagerProtocol Implementation

  func loadConfiguration() async throws -> Configuration {
    guard FileManager.default.fileExists(atPath: configFileURL.path) else {
      throw SettingsError.fileNotFound
    }

    do {
      let yamlData = try Data(contentsOf: configFileURL)
      let yamlString = String(data: yamlData, encoding: .utf8) ?? ""

      if yamlString.isEmpty {
        throw SettingsError.corruptedData
      }

      let configuration = try Configuration.fromYAML(yamlString)
      return configuration

    } catch CocoaError.fileReadNoPermission {
      throw SettingsError.permissionDenied
    } catch let error as SettingsError {
      throw error
    } catch {
      throw SettingsError.invalidFormat("YAML parsing error: \(error.localizedDescription)")
    }
  }

  func saveConfiguration(_ config: Configuration) async throws {
    do {
      // Ensure directory exists
      try Self.createConfigDirectoryIfNeeded(at: configDirectoryURL)

      // Generate YAML content
      let yamlContent = try config.toYAML()
      let yamlData = yamlContent.data(using: .utf8) ?? Data()

      // Write to file atomically
      try yamlData.write(to: configFileURL, options: .atomic)

      // Update current configuration
      currentConfig.value = config

      // Notify change handlers
      for handler in changeHandlers.value {
        handler(config)
      }

    } catch CocoaError.fileWriteNoPermission {
      throw SettingsError.permissionDenied
    } catch CocoaError.fileWriteVolumeReadOnly {
      throw SettingsError.permissionDenied
    } catch CocoaError.fileWriteFileExists {
      throw SettingsError.diskFull
    } catch let error as SettingsError {
      throw error
    } catch {
      throw SettingsError.invalidFormat(
        "Failed to save configuration: \(error.localizedDescription)")
    }
  }

  func resetToDefaults() async -> Configuration {
    let defaultConfig = Configuration()

    do {
      try await saveConfiguration(defaultConfig)
    } catch {
      // If save fails, at least update in memory
      currentConfig.value = defaultConfig
    }

    return defaultConfig
  }

  func onConfigurationChanged(_ handler: @escaping @Sendable (Configuration) -> Void) {
    changeHandlers.modify { $0.append(handler) }
  }

  // MARK: - Private Helper Methods

  private static func createConfigDirectoryIfNeeded(at url: URL) throws {
    guard !FileManager.default.fileExists(atPath: url.path) else {
      return
    }

    do {
      try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      throw SettingsError.permissionDenied
    }
  }

  private func backupCorruptedConfiguration() async throws {
    let backupURL = configFileURL.appendingPathExtension(
      "backup.\(Int(Date().timeIntervalSince1970))")

    do {
      if FileManager.default.fileExists(atPath: configFileURL.path) {
        try FileManager.default.copyItem(at: configFileURL, to: backupURL)
      }
    } catch {
      // If backup fails, continue with reset anyway
    }
  }
}

// MARK: - Legacy Compatibility

extension SettingsManager {
  /// Legacy method for backward compatibility
  func save() async throws {
    try await saveConfiguration(currentConfiguration)
  }

  /// Legacy method for backward compatibility
  func load() async throws {
    let loadedConfig = try await loadConfiguration()
    currentConfig.value = loadedConfig
  }
}

// MARK: - File System Utilities

extension SettingsManager {
  /// Check if the configuration file exists
  var configurationFileExists: Bool {
    FileManager.default.fileExists(atPath: configFileURL.path)
  }

  /// Get the size of the configuration file in bytes
  var configurationFileSize: Int64 {
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: configFileURL.path)
      return attributes[.size] as? Int64 ?? 0
    } catch {
      return 0
    }
  }

  /// Get the last modification date of the configuration file
  var configurationFileModificationDate: Date? {
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: configFileURL.path)
      return attributes[.modificationDate] as? Date
    } catch {
      return nil
    }
  }

  /// Export configuration to a specific file
  func exportConfiguration(to url: URL) async throws {
    let yamlContent = try currentConfiguration.toYAML()
    let yamlData = yamlContent.data(using: .utf8) ?? Data()
    try yamlData.write(to: url, options: .atomic)
  }

  /// Import configuration from a specific file
  func importConfiguration(from url: URL) async throws {
    let yamlData = try Data(contentsOf: url)
    let yamlString = String(data: yamlData, encoding: .utf8) ?? ""

    guard !yamlString.isEmpty else {
      throw SettingsError.corruptedData
    }

    let configuration = try Configuration.fromYAML(yamlString)
    try await saveConfiguration(configuration)
  }
}

// MARK: - YAML Testing Support

#if DEBUG
  extension SettingsManager {
    /// Load configuration from YAML string (for testing)
    func loadFromYAMLString(_ yamlString: String) async throws {
      let configuration = try Configuration.fromYAML(yamlString)
      currentConfig.value = configuration
    }

    /// Get current configuration as YAML string (for testing)
    func getCurrentConfigurationAsYAML() async throws -> String {
      return try currentConfiguration.toYAML()
    }
  }
#endif

// MARK: - Thread-Safe Box

private final class SendableBox<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var _value: T

  init(_ value: T) {
    _value = value
  }

  var value: T {
    get {
      lock.withLock { _value }
    }
    set {
      lock.withLock { _value = newValue }
    }
  }

  func modify<U>(_ transform: (inout T) -> U) -> U {
    lock.withLock {
      return transform(&_value)
    }
  }
}
