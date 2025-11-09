//
//  SettingsViewModel.swift
//  AltSwitch
//
//  Settings UI state management and configuration integration
//

import Foundation
import Observation
import SwiftUI

/// Settings view model for managing configuration UI state
@MainActor
@Observable
final class SettingsViewModel {

  // MARK: - Dependencies

  private let settingsManager: SettingsManagerProtocol
  private let hotkeyManager: HotkeyManagerProtocol?

  // MARK: - UI State

  /// Current configuration being edited
  private(set) var configuration: Configuration

  /// Whether there are unsaved changes
  private(set) var hasUnsavedChanges = false

  /// Loading state for async operations
  private(set) var isLoading = false

  /// Error message to display
  private(set) var errorMessage: String?

  /// Success message to display
  private(set) var successMessage: String?

  /// Validation errors for form fields
  private(set) var validationErrors: [String: String] = [:]

  // MARK: - Form State

  /// Whether settings are being reset
  private(set) var isResetting = false

  /// Whether hotkeys are being updated
  private(set) var isUpdatingHotkeys = false

  // MARK: - Convenience Properties

  var showHideHotkey: KeyCombo? {
    get { configuration.showHideHotkey }
    set { updateHotkey(.showHide, to: newValue) }
  }

  var settingsHotkey: KeyCombo? {
    get { configuration.settingsHotkey }
    set { updateHotkey(.settings, to: newValue) }
  }

  var refreshHotkey: KeyCombo? {
    get { configuration.refreshHotkey }
    set { updateHotkey(.refresh, to: newValue) }
  }

  var maxResults: Int {
    get { configuration.maxResults }
    set { updateMaxResults(newValue) }
  }

  var windowPosition: WindowPosition {
    get { configuration.windowPosition }
    set { updateWindowPosition(newValue) }
  }

  var enableFuzzySearch: Bool {
    get { configuration.enableFuzzySearch }
    set { updateEnableFuzzySearch(newValue) }
  }

  var showWindowCounts: Bool {
    get { configuration.showWindowCounts }
    set { updateShowWindowCounts(newValue) }
  }

  var enableSounds: Bool {
    get { configuration.enableSounds }
    set { updateEnableSounds(newValue) }
  }

  var enableAnimations: Bool {
    get { configuration.enableAnimations }
    set { updateEnableAnimations(newValue) }
  }

  var hotkeyInitDelay: TimeInterval {
    get { configuration.hotkeyInitDelay }
    set { updateHotkeyInitDelay(newValue) }
  }

  // MARK: - Initialization

  init(settingsManager: SettingsManagerProtocol, hotkeyManager: HotkeyManagerProtocol? = nil) {
    self.settingsManager = settingsManager
    self.hotkeyManager = hotkeyManager
    self.configuration = settingsManager.currentConfiguration.copy()

    // Listen for configuration changes from the settings manager
    settingsManager.onConfigurationChanged { [weak self] newConfig in
      Task { @MainActor [weak self] in
        guard let self = self else { return }
        // Only update if we don't have unsaved changes
        if !hasUnsavedChanges {
          configuration = newConfig.copy()
        }
      }
    }
  }

  // MARK: - Configuration Management

  /// Save the current configuration
  func saveConfiguration() async {
    isLoading = true
    clearMessages()

    do {
      // Validate configuration before saving
      let errors = configuration.validationErrors
      if !errors.isEmpty {
        errorMessage = "Validation failed: \(errors.joined(separator: ", "))"
        isLoading = false
        return
      }

      // Save to settings manager
      try await settingsManager.saveConfiguration(configuration)

      // Update hotkey manager if available
      if let hotkeyManager = hotkeyManager {
        try await updateHotkeyManager(hotkeyManager)
      }

      hasUnsavedChanges = false
      successMessage = "Settings saved successfully"

      // Clear success message after 3 seconds
      Task {
        try? await Task.sleep(for: .seconds(3))
        successMessage = nil
      }

    } catch {
      errorMessage = "Failed to save settings: \(error.localizedDescription)"
    }

    isLoading = false
  }

  /// Reset configuration to defaults
  func resetToDefaults() async {
    isResetting = true
    clearMessages()

    let defaultConfig = await settingsManager.resetToDefaults()
    configuration = defaultConfig.copy()
    hasUnsavedChanges = false
    successMessage = "Settings reset to defaults"

    // Clear success message after 3 seconds
    Task {
      try? await Task.sleep(for: .seconds(3))
      successMessage = nil
    }

    isResetting = false
  }

  /// Discard unsaved changes
  func discardChanges() {
    configuration = settingsManager.currentConfiguration.copy()
    hasUnsavedChanges = false
    clearMessages()
    validationErrors.removeAll()
  }

  // MARK: - Hotkey Management

  /// Update a specific hotkey
  private func updateHotkey(_ type: HotkeyType, to keyCombo: KeyCombo?) {
    switch type {
    case .showHide:
      configuration.showHideHotkey = keyCombo
    case .settings:
      configuration.settingsHotkey = keyCombo
    case .refresh:
      configuration.refreshHotkey = keyCombo
    }

    markAsChanged()
    validateHotkeys()

    // Auto-save hotkey changes immediately
    Task {
      await saveConfiguration()
      // MainViewModel will automatically pick up configuration changes
      // via the configuration observer and reload hotkeys with correct actions
    }
  }

  /// Update hotkey in the hotkey manager
  func updateHotkeyManager(_ hotkeyManager: HotkeyManagerProtocol) async throws {
    isUpdatingHotkeys = true

    defer {
      isUpdatingHotkeys = false
    }

    // Get all currently registered hotkeys and unregister them
    let currentHotkeys = hotkeyManager.getRegisteredHotkeys()
    for hotkey in currentHotkeys {
      try await hotkeyManager.unregisterHotkey(hotkey)
    }

    // Register new hotkeys with appropriate actions
    if let showHide = configuration.showHideHotkey {
      try await hotkeyManager.registerHotkey(showHide) {
        // This would typically trigger the main app switch functionality
        // For now, we'll just print - the actual implementation would come from MainViewModel
        print("Show/Hide hotkey triggered")
      }
    }

    if let settings = configuration.settingsHotkey {
      try await hotkeyManager.registerHotkey(settings) {
        // This would typically open settings
        print("Settings hotkey triggered")
      }
    }

    if let refresh = configuration.refreshHotkey {
      try await hotkeyManager.registerHotkey(refresh) {
        // This would typically refresh the app list
        print("Refresh hotkey triggered")
      }
    }
  }

  /// Validate hotkeys for conflicts
  private func validateHotkeys() {
    validationErrors.removeAll()

    let hotkeys = [
      ("showHide", configuration.showHideHotkey),
      ("settings", configuration.settingsHotkey),
      ("refresh", configuration.refreshHotkey),
    ].compactMap { $0.1 != nil ? ($0.0, $0.1!) : nil }

    // Check for duplicates
    var seenHotkeys: Set<KeyCombo> = []
    for (name, hotkey) in hotkeys {
      if seenHotkeys.contains(hotkey) {
        validationErrors[name] = "This hotkey conflicts with another setting"
      } else {
        seenHotkeys.insert(hotkey)
      }
    }

    // Check individual hotkey validity
    for (name, hotkey) in hotkeys {
      if !hotkey.isValid {
        validationErrors[name] = "Invalid hotkey: requires at least one modifier key"
      }

      if hotkey.hasSystemConflict {
        validationErrors[name] = "This hotkey conflicts with a system shortcut"
      }
    }
  }

  // MARK: - Property Updates

  private func updateMaxResults(_ value: Int) {
    configuration.maxResults = value
    markAsChanged()

    if value < 1 || value > 100 {
      validationErrors["maxResults"] = "Max results must be between 1 and 100"
    } else {
      validationErrors.removeValue(forKey: "maxResults")
    }
  }

  private func updateWindowPosition(_ value: WindowPosition) {
    configuration.windowPosition = value
    markAsChanged()
  }

  private func updateEnableFuzzySearch(_ value: Bool) {
    configuration.enableFuzzySearch = value
    markAsChanged()
  }

  private func updateShowWindowCounts(_ value: Bool) {
    configuration.showWindowCounts = value
    markAsChanged()
  }

  private func updateEnableSounds(_ value: Bool) {
    configuration.enableSounds = value
    markAsChanged()
  }

  private func updateEnableAnimations(_ value: Bool) {
    configuration.enableAnimations = value
    markAsChanged()
  }

  func applyHotkeyInitDelay(_ value: TimeInterval) async throws {
    let previousValue = configuration.hotkeyInitDelay
    updateHotkeyInitDelay(value)
    let clampedValue = configuration.hotkeyInitDelay

    do {
      try await settingsManager.updateHotkeyInitDelay(clampedValue)
      hasUnsavedChanges = false
    } catch {
      configuration.hotkeyInitDelay = previousValue
      hasUnsavedChanges = false
      errorMessage = "Failed to update hotkey delay: \(error.localizedDescription)"
      throw error
    }
  }

  private func updateHotkeyInitDelay(_ value: TimeInterval) {
    let clamped = min(max(value, 0), 0.1)
    configuration.hotkeyInitDelay = clamped
    markAsChanged()
  }

  // MARK: - State Management

  private func markAsChanged() {
    hasUnsavedChanges = true
    clearMessages()
  }

  private func clearMessages() {
    errorMessage = nil
    successMessage = nil
  }

  // MARK: - Validation

  /// Get validation status for a specific field
  func getValidationError(for field: String) -> String? {
    return validationErrors[field]
  }

  /// Check if a specific field has validation errors
  func hasValidationError(for field: String) -> Bool {
    return validationErrors[field] != nil
  }

  /// Get all validation errors
  var allValidationErrors: [String] {
    return Array(validationErrors.values)
  }

  /// Check if the configuration is valid
  var isValid: Bool {
    return validationErrors.isEmpty && configuration.isValid
  }
}

// MARK: - Factory Methods

extension SettingsViewModel {
  /// Create a view model with a settings manager
  static func create(with settingsManager: SettingsManagerProtocol) -> SettingsViewModel {
    return SettingsViewModel(settingsManager: settingsManager)
  }

  /// Create a view model with both settings and hotkey managers
  static func create(
    with settingsManager: SettingsManagerProtocol,
    hotkeyManager: HotkeyManagerProtocol
  ) -> SettingsViewModel {
    return SettingsViewModel(
      settingsManager: settingsManager,
      hotkeyManager: hotkeyManager
    )
  }
}
