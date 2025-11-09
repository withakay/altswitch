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
  case custom = "custom"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .altTab: return "Alt+Tab"
    case .cmdTab: return "Cmd+Tab"
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
    case .custom:
      return "Use a custom keyboard shortcut to show/hide AltSwitch"
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
}
