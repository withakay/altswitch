//
//  HotkeyOverrideState.swift
//  AltSwitch
//
//  Persists user selections for reserved Cmd/Alt-Tab overrides.
//

import Foundation

enum HotkeyMode: String, CaseIterable, Identifiable {
  case altTab = "altTab"
  case cmdTab = "cmdTab"
  case doubleTapOption = "doubleTapOption"
  case doubleTapCommand = "doubleTapCommand"
  case doubleTapControl = "doubleTapControl"
  case doubleTapShift = "doubleTapShift"
  case custom = "custom"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .altTab: return "Alt+Tab"
    case .cmdTab: return "Cmd+Tab"
    case .doubleTapOption: return "Double-tap Option"
    case .doubleTapCommand: return "Double-tap Command"
    case .doubleTapControl: return "Double-tap Control"
    case .doubleTapShift: return "Double-tap Shift"
    case .custom: return "Custom"
    }
  }

  var description: String {
    switch self {
    case .altTab:
      return "Alt+Tab will open AltSwitch instead of the system app switcher"
    case .cmdTab:
      return
        "Cmd+Tab will open AltSwitch instead of the system app switcher (requires accessibility permissions)"
    case .doubleTapOption:
      return "Double-tap ⌥ Option to open AltSwitch from anywhere"
    case .doubleTapCommand:
      return "Double-tap ⌘ Command to open AltSwitch without a key chord"
    case .doubleTapControl:
      return "Double-tap ⌃ Control to open AltSwitch from anywhere"
    case .doubleTapShift:
      return "Double-tap ⇧ Shift to open AltSwitch without a key chord"
    case .custom:
      return "Use a custom keyboard shortcut to show/hide AltSwitch"
    }
  }

  var doubleTapModifier: ModifierKey? {
    switch self {
    case .doubleTapOption: return .option
    case .doubleTapCommand: return .command
    case .doubleTapControl: return .control
    case .doubleTapShift: return .shift
    default: return nil
    }
  }
}

struct HotkeyOverrideState {
  private enum Keys {
    static let mode = "HotkeyMode"
    static let altTabEnabled = "AltSwitchAltTabOverride"
    static let cmdTabEnabled = "AltSwitchCmdTabOverride"
  }

  private var defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var mode: HotkeyMode {
    get {
      HotkeyMode(rawValue: defaults.string(forKey: Keys.mode) ?? HotkeyMode.custom.rawValue)
        ?? .custom
    }
    set {
      defaults.set(newValue.rawValue, forKey: Keys.mode)
    }
  }

  var isAltTabEnabled: Bool {
    get { defaults.bool(forKey: Keys.altTabEnabled) }
    set { defaults.set(newValue, forKey: Keys.altTabEnabled) }
  }

  var isCmdTabEnabled: Bool {
    get { defaults.bool(forKey: Keys.cmdTabEnabled) }
    set { defaults.set(newValue, forKey: Keys.cmdTabEnabled) }
  }

  var doubleTapModifier: ModifierKey? {
    mode.doubleTapModifier
  }
}
