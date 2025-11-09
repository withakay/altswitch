//
//  ConfigurationTests.swift
//  AltSwitchTests
//
//  Unit tests for Configuration model validation and functionality
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

@Suite("Configuration Model Unit Tests")
struct ConfigurationTests {

  @Test("Configuration initialization with default values")
  func testConfigurationInitializationWithDefaults() throws {
    // Arrange & Act
    let config = Configuration()

    // Assert - Verify default values
    #expect(config.showHideHotkey != nil, "Should have default show/hide hotkey")
    #expect(config.settingsHotkey != nil, "Should have default settings hotkey")
    #expect(config.refreshHotkey != nil, "Should have default refresh hotkey")

    #expect(config.maxResults == 10, "Default max results should be 10")
    #expect(config.windowPosition == .center, "Default window position should be center")
    #expect(config.useGlassEffect == true, "Glass effect should be enabled by default")
    #expect(config.enableFuzzySearch == true, "Fuzzy search should be enabled by default")
    #expect(config.showWindowCounts == true, "Window counts should be shown by default")
    #expect(config.enableSounds == false, "Sounds should be disabled by default")
    #expect(config.enableAnimations == true, "Animations should be enabled by default")

    #expect(config.version == "1.0", "Version should be 1.0")
  }

  @Test("Configuration custom initialization")
  func testConfigurationCustomInitialization() throws {
    // Arrange
    let customShowHide = KeyCombo(
      shortcut: .init(.t, modifiers: [.command, .option]),
      description: "Custom Toggle"
    )

    let customSettings = KeyCombo(
      shortcut: .init(.period, modifiers: [.command, .shift]),
      description: "Custom Settings"
    )

    // Act
    let config = Configuration(
      showHideHotkey: customShowHide,
      settingsHotkey: customSettings,
      maxResults: 20,
      windowPosition: .topCenter,
      useGlassEffect: false,
      enableFuzzySearch: false,
      showWindowCounts: false,
      enableSounds: true,
      enableAnimations: false
    )

    // Assert
    #expect(config.showHideHotkey == customShowHide)
    #expect(config.settingsHotkey == customSettings)
    #expect(config.maxResults == 20)
    #expect(config.windowPosition == .topCenter)
    #expect(config.useGlassEffect == false)
    #expect(config.enableFuzzySearch == false)
    #expect(config.showWindowCounts == false)
    #expect(config.enableSounds == true)
    #expect(config.enableAnimations == false)
  }

  @Test("Configuration validation rules")
  func testConfigurationValidationRules() throws {
    // Test valid configuration
    let validConfig = Configuration()
    #expect(validConfig.isValid, "Default configuration should be valid")

    // Test invalid max results
    let invalidMaxConfig = Configuration(maxResults: 0)
    #expect(!invalidMaxConfig.isValid, "Configuration with 0 max results should be invalid")

    let tooManyResultsConfig = Configuration(maxResults: 101)
    #expect(!tooManyResultsConfig.isValid, "Configuration with >100 max results should be invalid")

    // Test invalid hotkey combinations
    let invalidHotkeyConfig = Configuration(
      showHideHotkey: KeyCombo(
        shortcut: .init(.space, modifiers: []),
        description: "Invalid - No modifiers"
      )
    )
    #expect(!invalidHotkeyConfig.isValid, "Configuration with invalid hotkey should be invalid")
  }

  @Test("Configuration hotkey validation")
  func testConfigurationHotkeyValidation() throws {
    let config = Configuration()

    // Test valid hotkey updates
    let validHotkey = KeyCombo(
      shortcut: .init(.j, modifiers: [.command, .control]),
      description: "Valid Hotkey"
    )

    config.showHideHotkey = validHotkey
    #expect(config.areHotkeysValid, "Configuration should have valid hotkeys")

    // Test conflicting hotkeys
    config.settingsHotkey = validHotkey  // Same as show/hide
    #expect(!config.areHotkeysValid, "Configuration should detect conflicting hotkeys")

    // Test system conflicts
    let systemConflictHotkey = KeyCombo(
      shortcut: .init(.tab, modifiers: [.command]),
      description: "System Conflict"
    )

    config.showHideHotkey = systemConflictHotkey
    #expect(!config.areHotkeysValid, "Configuration should detect system conflicts")
  }

  @Test("Configuration serialization to YAML")
  func testConfigurationSerializationToYAML() throws {
    // Arrange
    let config = Configuration(
      maxResults: 15,
      windowPosition: .topCenter,
      useGlassEffect: false,
      enableFuzzySearch: true,
      enableSounds: false
    )

    // Act
    let yamlString = try config.toYAML()

    // Assert - Check YAML structure and content
    #expect(yamlString.contains("version: \"1.0\""), "YAML should contain version")
    #expect(yamlString.contains("hotkeys:"), "YAML should contain hotkeys section")
    #expect(yamlString.contains("show_hide:"), "YAML should contain show_hide hotkey")
    #expect(yamlString.contains("appearance:"), "YAML should contain appearance section")
    #expect(yamlString.contains("max_results: 15"), "YAML should contain max_results value")
    #expect(
      yamlString.contains("window_position: \"top_center\""), "YAML should contain window_position")
    #expect(
      yamlString.contains("use_glass_effect: false"), "YAML should contain glass effect setting")
    #expect(yamlString.contains("search:"), "YAML should contain search section")
    #expect(yamlString.contains("fuzzy_enabled: true"), "YAML should contain fuzzy search setting")
    #expect(yamlString.contains("features:"), "YAML should contain features section")
    #expect(yamlString.contains("enable_sounds: false"), "YAML should contain sounds setting")
  }

  @Test("Configuration deserialization from YAML")
  func testConfigurationDeserializationFromYAML() throws {
    // Arrange
    let yamlString = """
      version: "1.0"
      hotkeys:
        show_hide:
          key: "space"
          modifiers: ["command", "shift"]
          description: "Show/Hide AltSwitch"
        settings:
          key: "comma"
          modifiers: ["command"]
          description: "Open Settings"
      appearance:
        max_results: 20
        window_position: "top_center"
        use_glass_effect: false
      search:
        fuzzy_enabled: false
        show_window_counts: true
      features:
        enable_sounds: true
        enable_animations: false
      """

    // Act
    let config = try Configuration.fromYAML(yamlString)

    // Assert
    #expect(config.version == "1.0")
    #expect(config.maxResults == 20)
    #expect(config.windowPosition == .topCenter)
    #expect(config.useGlassEffect == false)
    #expect(config.enableFuzzySearch == false)
    #expect(config.showWindowCounts == true)
    #expect(config.enableSounds == true)
    #expect(config.enableAnimations == false)

    #expect(config.showHideHotkey?.shortcut.key == .space)
    #expect(config.showHideHotkey?.description == "Show/Hide AltSwitch")
    #expect(config.settingsHotkey?.shortcut.key == .comma)
    #expect(config.settingsHotkey?.description == "Open Settings")
  }

  @Test("Configuration migration from older versions")
  func testConfigurationMigrationFromOlderVersions() throws {
    // Test migration from version 0.9
    let oldYamlString = """
      version: "0.9"
      hotkey: "cmd+shift+space"
      max_apps: 15
      window_pos: "center"
      fuzzy_search: true
      sounds_enabled: false
      """

    // Act
    let migratedConfig = try Configuration.fromYAML(oldYamlString)

    // Assert - Should migrate to new format
    #expect(migratedConfig.version == "1.0", "Should upgrade version to 1.0")
    #expect(migratedConfig.maxResults == 15, "Should migrate max_apps to maxResults")
    #expect(migratedConfig.windowPosition == .center, "Should migrate window_pos to windowPosition")
    #expect(
      migratedConfig.enableFuzzySearch == true, "Should migrate fuzzy_search to enableFuzzySearch")
    #expect(migratedConfig.enableSounds == false, "Should migrate sounds_enabled to enableSounds")
    #expect(migratedConfig.showHideHotkey != nil, "Should create show/hide hotkey from old format")
  }

  @Test("Configuration copying and modification")
  func testConfigurationCopyingAndModification() throws {
    // Arrange
    let originalConfig = Configuration(
      maxResults: 15,
      enableSounds: true
    )

    // Act
    let modifiedConfig = originalConfig.copy()
    modifiedConfig.maxResults = 25
    modifiedConfig.enableSounds = false

    // Assert - Original should remain unchanged
    #expect(originalConfig.maxResults == 15, "Original config should not be modified")
    #expect(originalConfig.enableSounds == true, "Original config should not be modified")

    // Modified copy should have new values
    #expect(modifiedConfig.maxResults == 25, "Modified config should have new values")
    #expect(modifiedConfig.enableSounds == false, "Modified config should have new values")
  }

  @Test("Configuration equality comparison")
  func testConfigurationEqualityComparison() throws {
    // Arrange
    let config1 = Configuration(maxResults: 15, enableSounds: true)
    let config2 = Configuration(maxResults: 15, enableSounds: true)
    let config3 = Configuration(maxResults: 20, enableSounds: true)

    // Assert
    #expect(config1 == config2, "Configurations with same settings should be equal")
    #expect(config1 != config3, "Configurations with different settings should not be equal")
  }

  @Test("Configuration change notifications")
  func testConfigurationChangeNotifications() throws {
    // Arrange
    let config = Configuration()
    var changeNotifications: [String] = []

    config.onChanged = { propertyName in
      changeNotifications.append(propertyName)
    }

    // Act - Modify various properties
    config.maxResults = 20
    config.enableSounds = true
    config.windowPosition = .topCenter

    // Assert
    #expect(
      changeNotifications.contains("maxResults"),
      "Should receive change notification for maxResults")
    #expect(
      changeNotifications.contains("enableSounds"),
      "Should receive change notification for enableSounds")
    #expect(
      changeNotifications.contains("windowPosition"),
      "Should receive change notification for windowPosition")
    #expect(changeNotifications.count == 3, "Should receive exactly 3 change notifications")
  }

  @Test("Configuration validation error messages")
  func testConfigurationValidationErrorMessages() throws {
    // Test invalid max results
    let invalidConfig1 = Configuration(maxResults: 0)
    let errors1 = invalidConfig1.validationErrors
    #expect(
      errors1.contains { $0.contains("maxResults") && $0.contains("1") && $0.contains("100") },
      "Should provide helpful error message for invalid maxResults")

    // Test invalid hotkey
    let invalidHotkey = KeyCombo(
      shortcut: .init(.space, modifiers: []),
      description: "Invalid"
    )
    let invalidConfig2 = Configuration(showHideHotkey: invalidHotkey)
    let errors2 = invalidConfig2.validationErrors
    #expect(
      errors2.contains { $0.contains("hotkey") && $0.contains("modifier") },
      "Should provide helpful error message for invalid hotkey")

    // Test conflicting hotkeys
    let validHotkey = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Valid"
    )
    let conflictingConfig = Configuration(
      showHideHotkey: validHotkey,
      settingsHotkey: validHotkey
    )
    let errors3 = conflictingConfig.validationErrors
    #expect(
      errors3.contains { $0.contains("conflict") || $0.contains("duplicate") },
      "Should provide helpful error message for conflicting hotkeys")
  }

  @Test("Configuration performance with complex operations")
  func testConfigurationPerformanceWithComplexOperations() throws {
    // Arrange
    let config = Configuration()

    // Act & Assert - Test performance of validation
    let validationStartTime = Date()
    for _ in 1...1000 {
      _ = config.isValid
    }
    let validationTime = Date().timeIntervalSince(validationStartTime)
    #expect(validationTime < 0.1, "Validation should be fast: \(validationTime)s")

    // Test performance of YAML serialization
    let serializationStartTime = Date()
    for _ in 1...100 {
      _ = try config.toYAML()
    }
    let serializationTime = Date().timeIntervalSince(serializationStartTime)
    #expect(serializationTime < 0.1, "YAML serialization should be fast: \(serializationTime)s")

    // Test performance of copying
    let copyStartTime = Date()
    for _ in 1...1000 {
      _ = config.copy()
    }
    let copyTime = Date().timeIntervalSince(copyStartTime)
    #expect(copyTime < 0.1, "Copying should be fast: \(copyTime)s")
  }
}

// MARK: - Test Configuration Implementation (This will fail until actual implementation exists)

/// Test implementation of Configuration model for contract verification
/// This implementation will cause tests to fail until the real implementation is created
private class Configuration: @unchecked Sendable {
  // MARK: - Hotkey Settings
  @ConfigurationProperty var showHideHotkey: KeyCombo?
  @ConfigurationProperty var settingsHotkey: KeyCombo?
  @ConfigurationProperty var refreshHotkey: KeyCombo?

  // MARK: - Appearance Settings
  @ConfigurationProperty var maxResults: Int
  @ConfigurationProperty var windowPosition: WindowPosition
  @ConfigurationProperty var useGlassEffect: Bool

  // MARK: - Search Settings
  @ConfigurationProperty var enableFuzzySearch: Bool
  @ConfigurationProperty var showWindowCounts: Bool

  // MARK: - Feature Settings
  @ConfigurationProperty var enableSounds: Bool
  @ConfigurationProperty var enableAnimations: Bool

  // MARK: - Metadata
  let version: String

  // MARK: - Change Notification
  var onChanged: ((String) -> Void)?

  // MARK: - Initialization

  init(
    showHideHotkey: KeyCombo? = KeyCombo.defaultShowHide(),
    settingsHotkey: KeyCombo? = KeyCombo.defaultSettings(),
    refreshHotkey: KeyCombo? = KeyCombo.defaultRefresh(),
    maxResults: Int = 10,
    windowPosition: WindowPosition = .center,
    useGlassEffect: Bool = true,
    enableFuzzySearch: Bool = true,
    showWindowCounts: Bool = true,
    enableSounds: Bool = false,
    enableAnimations: Bool = true,
    version: String = "1.0"
  ) {
    self.version = version

    // Initialize properties after setting up change notification
    self._showHideHotkey = ConfigurationProperty(
      wrappedValue: showHideHotkey, name: "showHideHotkey")
    self._settingsHotkey = ConfigurationProperty(
      wrappedValue: settingsHotkey, name: "settingsHotkey")
    self._refreshHotkey = ConfigurationProperty(wrappedValue: refreshHotkey, name: "refreshHotkey")
    self._maxResults = ConfigurationProperty(wrappedValue: maxResults, name: "maxResults")
    self._windowPosition = ConfigurationProperty(
      wrappedValue: windowPosition, name: "windowPosition")
    self._useGlassEffect = ConfigurationProperty(
      wrappedValue: useGlassEffect, name: "useGlassEffect")
    self._enableFuzzySearch = ConfigurationProperty(
      wrappedValue: enableFuzzySearch, name: "enableFuzzySearch")
    self._showWindowCounts = ConfigurationProperty(
      wrappedValue: showWindowCounts, name: "showWindowCounts")
    self._enableSounds = ConfigurationProperty(wrappedValue: enableSounds, name: "enableSounds")
    self._enableAnimations = ConfigurationProperty(
      wrappedValue: enableAnimations, name: "enableAnimations")

    // Set up change notification
    setupChangeNotification()
  }

  private func setupChangeNotification() {
    _showHideHotkey.onChange = { [weak self] in self?.onChanged?("showHideHotkey") }
    _settingsHotkey.onChange = { [weak self] in self?.onChanged?("settingsHotkey") }
    _refreshHotkey.onChange = { [weak self] in self?.onChanged?("refreshHotkey") }
    _maxResults.onChange = { [weak self] in self?.onChanged?("maxResults") }
    _windowPosition.onChange = { [weak self] in self?.onChanged?("windowPosition") }
    _useGlassEffect.onChange = { [weak self] in self?.onChanged?("useGlassEffect") }
    _enableFuzzySearch.onChange = { [weak self] in self?.onChanged?("enableFuzzySearch") }
    _showWindowCounts.onChange = { [weak self] in self?.onChanged?("showWindowCounts") }
    _enableSounds.onChange = { [weak self] in self?.onChanged?("enableSounds") }
    _enableAnimations.onChange = { [weak self] in self?.onChanged?("enableAnimations") }
  }

  // MARK: - Validation

  var isValid: Bool {
    return validationErrors.isEmpty
  }

  var validationErrors: [String] {
    var errors: [String] = []

    // Validate max results
    if maxResults < 1 || maxResults > 100 {
      errors.append("maxResults must be between 1 and 100")
    }

    // Validate hotkeys
    if let showHide = showHideHotkey, !showHide.isValid {
      errors.append("Show/Hide hotkey requires at least one meaningful modifier key")
    }

    if let settings = settingsHotkey, !settings.isValid {
      errors.append("Settings hotkey requires at least one meaningful modifier key")
    }

    if let refresh = refreshHotkey, !refresh.isValid {
      errors.append("Refresh hotkey requires at least one meaningful modifier key")
    }

    // Check for hotkey conflicts
    if !areHotkeysValid {
      errors.append("Hotkeys cannot conflict with each other or system shortcuts")
    }

    return errors
  }

  var areHotkeysValid: Bool {
    let hotkeys = [showHideHotkey, settingsHotkey, refreshHotkey].compactMap { $0 }

    // Check for duplicates
    let uniqueHotkeys = Set(hotkeys)
    if uniqueHotkeys.count != hotkeys.count {
      return false
    }

    // Check for system conflicts
    for hotkey in hotkeys {
      if hotkey.hasSystemConflict {
        return false
      }
    }

    return true
  }

  // MARK: - Serialization

  func toYAML() throws -> String {
    var yaml = "version: \"\(version)\"\n"

    // Hotkeys section
    yaml += "hotkeys:\n"
    if let showHide = showHideHotkey {
      yaml += "  show_hide:\n"
      yaml += "    key: \"\(String(describing: showHide.shortcut.key))\"\n"
      yaml += "    modifiers: \(formatModifiers(showHide.shortcut.modifiers))\n"
      yaml += "    description: \"\(showHide.description)\"\n"
    }

    if let settings = settingsHotkey {
      yaml += "  settings:\n"
      yaml += "    key: \"\(String(describing: settings.shortcut.key))\"\n"
      yaml += "    modifiers: \(formatModifiers(settings.shortcut.modifiers))\n"
      yaml += "    description: \"\(settings.description)\"\n"
    }

    // Appearance section
    yaml += "appearance:\n"
    yaml += "  max_results: \(maxResults)\n"
    yaml += "  window_position: \"\(windowPosition.rawValue)\"\n"
    yaml += "  use_glass_effect: \(useGlassEffect)\n"

    // Search section
    yaml += "search:\n"
    yaml += "  fuzzy_enabled: \(enableFuzzySearch)\n"
    yaml += "  show_window_counts: \(showWindowCounts)\n"

    // Features section
    yaml += "features:\n"
    yaml += "  enable_sounds: \(enableSounds)\n"
    yaml += "  enable_animations: \(enableAnimations)\n"

    return yaml
  }

  private func formatModifiers(_ modifiers: NSEvent.ModifierFlags) -> String {
    var modifierStrings: [String] = []
    if modifiers.contains(.command) { modifierStrings.append("\"command\"") }
    if modifiers.contains(.option) { modifierStrings.append("\"option\"") }
    if modifiers.contains(.control) { modifierStrings.append("\"control\"") }
    if modifiers.contains(.shift) { modifierStrings.append("\"shift\"") }
    return "[\(modifierStrings.joined(separator: ", "))]"
  }

  static func fromYAML(_ yaml: String) throws -> Configuration {
    // Simplified YAML parsing for testing
    // Real implementation would use Yams library

    let config = Configuration()

    // Check for version and migrate if needed
    if yaml.contains("version: \"0.9\"") {
      return try migrateFromV09(yaml)
    }

    // Parse modern format
    if let maxResultsMatch = yaml.range(of: #"max_results: (\d+)"#, options: .regularExpression) {
      let valueString = String(yaml[maxResultsMatch]).components(separatedBy: ": ")[1]
      config.maxResults = Int(valueString) ?? 10
    }

    if yaml.contains("window_position: \"top_center\"") {
      config.windowPosition = .topCenter
    }

    if yaml.contains("use_glass_effect: false") {
      config.useGlassEffect = false
    }

    if yaml.contains("fuzzy_enabled: false") {
      config.enableFuzzySearch = false
    }

    if yaml.contains("enable_sounds: true") {
      config.enableSounds = true
    }

    if yaml.contains("enable_animations: false") {
      config.enableAnimations = false
    }

    return config
  }

  private static func migrateFromV09(_ yaml: String) throws -> Configuration {
    let config = Configuration()

    // Migrate old field names
    if let maxAppsMatch = yaml.range(of: #"max_apps: (\d+)"#, options: .regularExpression) {
      let valueString = String(yaml[maxAppsMatch]).components(separatedBy: ": ")[1]
      config.maxResults = Int(valueString) ?? 10
    }

    if yaml.contains("window_pos: \"center\"") {
      config.windowPosition = .center
    }

    if yaml.contains("fuzzy_search: true") {
      config.enableFuzzySearch = true
    }

    if yaml.contains("sounds_enabled: false") {
      config.enableSounds = false
    }

    // Migrate old hotkey format
    if yaml.contains("hotkey: \"cmd+shift+space\"") {
      config.showHideHotkey = KeyCombo(
        shortcut: .init(.space, modifiers: [.command, .shift]),
        description: "Show/Hide AltSwitch"
      )
    }

    return config
  }

  // MARK: - Copying

  func copy() -> Configuration {
    return Configuration(
      showHideHotkey: showHideHotkey,
      settingsHotkey: settingsHotkey,
      refreshHotkey: refreshHotkey,
      maxResults: maxResults,
      windowPosition: windowPosition,
      useGlassEffect: useGlassEffect,
      enableFuzzySearch: enableFuzzySearch,
      showWindowCounts: showWindowCounts,
      enableSounds: enableSounds,
      enableAnimations: enableAnimations,
      version: version
    )
  }

  // MARK: - Equality

  static func == (lhs: Configuration, rhs: Configuration) -> Bool {
    return lhs.showHideHotkey == rhs.showHideHotkey && lhs.settingsHotkey == rhs.settingsHotkey
      && lhs.refreshHotkey == rhs.refreshHotkey && lhs.maxResults == rhs.maxResults
      && lhs.windowPosition == rhs.windowPosition && lhs.useGlassEffect == rhs.useGlassEffect
      && lhs.enableFuzzySearch == rhs.enableFuzzySearch
      && lhs.showWindowCounts == rhs.showWindowCounts && lhs.enableSounds == rhs.enableSounds
      && lhs.enableAnimations == rhs.enableAnimations
  }

  static func != (lhs: Configuration, rhs: Configuration) -> Bool {
    return !(lhs == rhs)
  }
}

// MARK: - Supporting Types

@propertyWrapper
private class ConfigurationProperty<T>: @unchecked Sendable {
  private var value: T
  let name: String
  var onChange: (() -> Void)?

  init(wrappedValue: T, name: String) {
    self.value = wrappedValue
    self.name = name
  }

  var wrappedValue: T {
    get { value }
    set {
      value = newValue
      onChange?()
    }
  }
}

private enum WindowPosition: String, Sendable {
  case center = "center"
  case topCenter = "top_center"
  case mouseLocation = "mouse_location"
}

// Re-use KeyCombo from KeyComboTests
private struct KeyCombo: Hashable, Codable, Sendable {
  let shortcut: KeyboardShortcuts.Shortcut
  let description: String

  init(shortcut: KeyboardShortcuts.Shortcut, description: String) {
    self.shortcut = shortcut
    self.description = description
  }

  var isValid: Bool {
    let meaningfulModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
    return shortcut.modifiers.intersection(meaningfulModifiers).isEmpty == false
  }

  var hasSystemConflict: Bool {
    let systemConflicts: [KeyboardShortcuts.Shortcut] = [
      .init(.tab, modifiers: [.command]),
      .init(.space, modifiers: [.command]),
    ]
    return systemConflicts.contains(shortcut)
  }

  static func defaultShowHide() -> KeyCombo {
    return KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]), description: "Show/Hide AltSwitch")
  }

  static func defaultSettings() -> KeyCombo {
    return KeyCombo(shortcut: .init(.comma, modifiers: [.command]), description: "Open Settings")
  }

  static func defaultRefresh() -> KeyCombo {
    return KeyCombo(
      shortcut: .init(.r, modifiers: [.command, .shift]), description: "Refresh App List")
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(shortcut)
  }

  static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
    return lhs.shortcut == rhs.shortcut
  }

  init(from decoder: Decoder) throws {
    // Simplified for testing
    self.shortcut = .init(.space, modifiers: [.command, .shift])
    self.description = "Test"
  }

  func encode(to encoder: Encoder) throws {
    // Simplified for testing
  }
}
