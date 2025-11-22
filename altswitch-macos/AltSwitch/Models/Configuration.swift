//
//  Configuration.swift
//  AltSwitch
//
//  User settings and preferences with YAML persistence
//

import AppKit
import Foundation
import KeyboardShortcuts
import Yams

enum WindowPosition: String, CaseIterable, Codable {
  case center = "center"
  case topCenter = "top_center"
  case bottomCenter = "bottom_center"
}

@Observable
final class Configuration: @unchecked Sendable {
  var showHotkey: KeyCombo
  var maxResults: Int
  var windowPosition: WindowPosition
  var appearanceDelay: TimeInterval
  var searchDelay: TimeInterval
  var hotkeyInitDelay: TimeInterval

  // Feature flags
  var enableFuzzySearch: Bool
  var showWindowCounts: Bool
  var enableSounds: Bool
  var enableAnimations: Bool
  var restrictToMainDisplay: Bool
  var showIndividualWindows: Bool

  // Window filtering
  var applicationNameExcludeList: Set<String>
  var untitledWindowExcludeList: Set<String>

  // Additional hotkeys (optional for compatibility)
  var showHideHotkey: KeyCombo? {
    get { showHotkey }
    set { if let value = newValue { showHotkey = value } }
  }
  var settingsHotkey: KeyCombo?
  var refreshHotkey: KeyCombo?

  // Validation support - computed properties (not stored)
  var validationErrors: [String] { [] }
  var isValid: Bool { validationErrors.isEmpty }
  var areHotkeysValid: Bool { true }

  init(
    showHotkey: KeyCombo = .showHide,
    maxResults: Int = 10,
    windowPosition: WindowPosition = .center,
    appearanceDelay: TimeInterval = 0.1,
    searchDelay: TimeInterval = 0.05,
    hotkeyInitDelay: TimeInterval = 0.1,
    enableFuzzySearch: Bool = true,
    showWindowCounts: Bool = false,
    enableSounds: Bool = false,
    enableAnimations: Bool = true,
    restrictToMainDisplay: Bool = false,
    showIndividualWindows: Bool = true,
    applicationNameExcludeList: Set<String> = [],
    untitledWindowExcludeList: Set<String> = [],
    settingsHotkey: KeyCombo? = nil,
    refreshHotkey: KeyCombo? = nil
  ) {
    // Validation
    precondition(maxResults >= 5 && maxResults <= 50, "Max results must be in range 5-50")
    precondition(
      appearanceDelay >= 0.05 && appearanceDelay <= 0.5,
      "Appearance delay must be in range 0.05-0.5 seconds")
    precondition(
      searchDelay >= 0.01 && searchDelay <= 0.1,
      "Search delay must be in range 0.01-0.1 seconds")
    precondition(
      hotkeyInitDelay >= 0 && hotkeyInitDelay <= 0.1,
      "Hotkey init delay must be in range 0-0.1 seconds")

    self.showHotkey = showHotkey
    self.maxResults = maxResults
    self.windowPosition = windowPosition
    self.appearanceDelay = appearanceDelay
    self.searchDelay = searchDelay
    self.hotkeyInitDelay = hotkeyInitDelay
    self.enableFuzzySearch = enableFuzzySearch
    self.showWindowCounts = showWindowCounts
    self.enableSounds = enableSounds
    self.enableAnimations = enableAnimations
    self.restrictToMainDisplay = restrictToMainDisplay
    self.showIndividualWindows = showIndividualWindows
    self.applicationNameExcludeList = applicationNameExcludeList
    self.untitledWindowExcludeList = untitledWindowExcludeList
    self.settingsHotkey = settingsHotkey
    self.refreshHotkey = refreshHotkey
  }
}

// MARK: - YAML Persistence

extension Configuration {
  // swiftlint:disable nesting
  private struct YAMLRepresentation: Codable {
    let version: String
    let hotkeys: HotkeysConfig
    let appearance: AppearanceConfig
    let search: SearchConfig
    let features: FeaturesConfig
    let filtering: FilteringConfig?

    struct HotkeysConfig: Codable {
      let showHide: HotkeyConfig

      struct HotkeyConfig: Codable {
        let key: String
        let modifiers: [String]
      }

      enum CodingKeys: String, CodingKey {
        case showHide = "show_hide"
      }
    }

    struct AppearanceConfig: Codable {
      let maxResults: Int
      let windowPosition: String
      let appearanceDelay: Double
      let hotkeyInitDelay: Double?

      enum CodingKeys: String, CodingKey {
        case maxResults = "max_results"
        case windowPosition = "window_position"
        case appearanceDelay = "appearance_delay"
        case hotkeyInitDelay = "hotkey_init_delay"
      }
    }

    struct SearchConfig: Codable {
      let fuzzyEnabled: Bool
      let searchDelay: Double
      let showWindowCounts: Bool
      let showIndividualWindows: Bool?

      enum CodingKeys: String, CodingKey {
        case fuzzyEnabled = "fuzzy_enabled"
        case searchDelay = "search_delay"
        case showWindowCounts = "show_window_counts"
        case showIndividualWindows = "show_individual_windows"
      }
    }

    struct FeaturesConfig: Codable {
      let enableSounds: Bool
      let restrictToMainDisplay: Bool?

      enum CodingKeys: String, CodingKey {
        case enableSounds = "enable_sounds"
        case restrictToMainDisplay = "restrict_to_main_display"
      }
    }

    struct FilteringConfig: Codable {
      let applicationNameExcludeList: [String]?
      let untitledWindowExcludeList: [String]?

      enum CodingKeys: String, CodingKey {
        case applicationNameExcludeList = "application_name_exclude_list"
        case untitledWindowExcludeList = "untitled_window_exclude_list"
      }
    }
    // swiftlint:enable nesting
  }

  func toYAML() throws -> String {
    let yaml = YAMLRepresentation(
      version: "1.0",
      hotkeys: .init(
        showHide: .init(
          key: keyToString(showHotkey.shortcut.key ?? .space),
          modifiers: modifiersToStrings(showHotkey.shortcut.modifiers)
        )
      ),
      appearance: .init(
        maxResults: maxResults,
        windowPosition: windowPosition.rawValue,
        appearanceDelay: appearanceDelay,
        hotkeyInitDelay: hotkeyInitDelay
      ),
      search: .init(
        fuzzyEnabled: enableFuzzySearch,
        searchDelay: searchDelay,
        showWindowCounts: showWindowCounts,
        showIndividualWindows: showIndividualWindows
      ),
      features: .init(
        enableSounds: enableSounds,
        restrictToMainDisplay: restrictToMainDisplay
      ),
      filtering: .init(
        applicationNameExcludeList: Array(applicationNameExcludeList).sorted(),
        untitledWindowExcludeList: Array(untitledWindowExcludeList).sorted()
      )
    )

    return try YAMLEncoder().encode(yaml)
  }

  static func fromYAML(_ yamlString: String) throws -> Configuration {
    let yaml = try YAMLDecoder().decode(YAMLRepresentation.self, from: yamlString)

    let key = try keyFromString(yaml.hotkeys.showHide.key)
    let modifiers: NSEvent.ModifierFlags = NSEvent.ModifierFlags(
      yaml.hotkeys.showHide.modifiers.compactMap(modifierFromString))
    let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    let showHotkey = KeyCombo(shortcut: shortcut, description: "Show/Hide AltSwitch")

    // Migration: hotkeyInitDelay might not exist in older configs
    let hotkeyInitDelay = yaml.appearance.hotkeyInitDelay ?? 0.1  // Default to 100ms
    
    // Migration: filtering might not exist in older configs
    let applicationNameExcludeList = Set(yaml.filtering?.applicationNameExcludeList ?? [])
    let untitledWindowExcludeList = Set(yaml.filtering?.untitledWindowExcludeList ?? [])
    
    return Configuration(
      showHotkey: showHotkey,
      maxResults: yaml.appearance.maxResults,
      windowPosition: WindowPosition(rawValue: yaml.appearance.windowPosition) ?? .center,
      appearanceDelay: yaml.appearance.appearanceDelay,
      searchDelay: yaml.search.searchDelay,
      hotkeyInitDelay: hotkeyInitDelay,
      enableFuzzySearch: yaml.search.fuzzyEnabled,
      showWindowCounts: yaml.search.showWindowCounts,
      enableSounds: yaml.features.enableSounds,
      restrictToMainDisplay: yaml.features.restrictToMainDisplay ?? false,
      showIndividualWindows: yaml.search.showIndividualWindows ?? true,
      applicationNameExcludeList: applicationNameExcludeList,
      untitledWindowExcludeList: untitledWindowExcludeList,
      settingsHotkey: nil,
      refreshHotkey: nil
    )
  }

  private func keyToString(_ key: KeyboardShortcuts.Key) -> String {
    switch key {
    case .space: return "space"
    case .return: return "return"
    case .tab: return "tab"
    case .escape: return "escape"
    case .comma: return "comma"
    default: return String(describing: key)
    }
  }

  private static func keyFromString(_ string: String) throws -> KeyboardShortcuts.Key {
    switch string.lowercased() {
    case "space": return .space
    case "return": return .return
    case "tab": return .tab
    case "escape": return .escape
    case "comma": return .comma
    default:
      throw ConfigurationError.invalidKey(string)
    }
  }

  private func modifiersToStrings(_ modifiers: NSEvent.ModifierFlags) -> [String] {
    var result: [String] = []
    if modifiers.contains(.command) { result.append("command") }
    if modifiers.contains(.shift) { result.append("shift") }
    if modifiers.contains(.option) { result.append("option") }
    if modifiers.contains(.control) { result.append("control") }
    return result
  }

  private static func modifierFromString(_ string: String) -> NSEvent.ModifierFlags? {
    switch string.lowercased() {
    case "command": return .command
    case "shift": return .shift
    case "option": return .option
    case "control": return .control
    default: return nil
    }
  }
}

// MARK: - Errors
enum ConfigurationError: Error {
  case invalidKey(String)
  case invalidModifier(String)
  case fileNotFound(String)
  case invalidFormat(String)
}

// MARK: - Copy Support
extension Configuration {
  /// Creates a copy of this configuration
  func copy() -> Configuration {
    return Configuration(
      showHotkey: showHotkey,
      maxResults: maxResults,
      windowPosition: windowPosition,
      appearanceDelay: appearanceDelay,
      searchDelay: searchDelay,
      hotkeyInitDelay: hotkeyInitDelay,
      enableFuzzySearch: enableFuzzySearch,
      showWindowCounts: showWindowCounts,
      enableSounds: enableSounds,
      enableAnimations: enableAnimations,
      restrictToMainDisplay: restrictToMainDisplay,
      showIndividualWindows: showIndividualWindows,
      applicationNameExcludeList: applicationNameExcludeList,
      untitledWindowExcludeList: untitledWindowExcludeList,
      settingsHotkey: settingsHotkey,
      refreshHotkey: refreshHotkey
    )
  }
}
