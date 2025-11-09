//
//  KeyCombo.swift
//  AltSwitch
//
//  Represents keyboard shortcut combinations for hotkeys
//

import AppKit
import Foundation
import KeyboardShortcuts

struct KeyCombo: Hashable, Sendable {
  let shortcut: KeyboardShortcuts.Shortcut
  let description: String

  init(shortcut: KeyboardShortcuts.Shortcut, description: String = "") {
    // Validation
    precondition(!shortcut.modifiers.isEmpty, "Must have at least one modifier key")

    self.shortcut = shortcut
    self.description = description
  }

  // Default combinations
  static let showHide = KeyCombo(
    shortcut: KeyboardShortcuts.Shortcut(.space, modifiers: [.command, .shift]),
    description: "Show/Hide AltSwitch"
  )

  static let settings = KeyCombo(
    shortcut: KeyboardShortcuts.Shortcut(.comma, modifiers: [.command]),
    description: "Open Settings"
  )

  static let refresh = KeyCombo(
    shortcut: KeyboardShortcuts.Shortcut(.r, modifiers: [.command, .shift]),
    description: "Refresh App List"
  )
}

// MARK: - Display Properties
extension KeyCombo {
  /// Human-readable display string (e.g., "⌘⇧Space")
  var displayString: String {
    // Build our own display string since shortcut.description is MainActor isolated
    var result = ""
    if shortcut.modifiers.contains(.command) { result += "⌘" }
    if shortcut.modifiers.contains(.shift) { result += "⇧" }
    if shortcut.modifiers.contains(.option) { result += "⌥" }
    if shortcut.modifiers.contains(.control) { result += "⌃" }

    if let key = shortcut.key {
      result += keySymbol(for: key)
    }

    return result
  }

  private func keySymbol(for key: KeyboardShortcuts.Key) -> String {
    switch key {
    case .space: return "Space"
    case .return: return "↩"
    case .tab: return "⇥"
    case .escape: return "⎋"
    case .comma: return ","
    default: return String(describing: key).capitalized
    }
  }

  /// Accessibility-friendly description
  var accessibilityDescription: String {
    var components: [String] = []

    if shortcut.modifiers.contains(.command) { components.append("Command") }
    if shortcut.modifiers.contains(.shift) { components.append("Shift") }
    if shortcut.modifiers.contains(.option) { components.append("Option") }
    if shortcut.modifiers.contains(.control) { components.append("Control") }

    if let key = shortcut.key {
      components.append(keyName(for: key))
    }

    return components.joined(separator: " ")
  }

  private func keyName(for key: KeyboardShortcuts.Key) -> String {
    switch key {
    case .space: return "Space"
    case .return: return "Return"
    case .tab: return "Tab"
    case .escape: return "Escape"
    case .delete: return "Delete"
    case .comma: return "Comma"
    default: return String(describing: key).capitalized
    }
  }
}

// MARK: - Validation
extension KeyCombo {
  /// Validates if the key combination is suitable for global hotkey registration
  var isValidForGlobalHotkey: Bool {
    // Must have at least one modifier
    guard !shortcut.modifiers.isEmpty else { return false }

    // Check if key exists
    guard let key = shortcut.key else { return false }

    // Specific keys that should have modifiers
    let keysRequiringModifiers: Set<KeyboardShortcuts.Key> = [
      .space, .tab, .return, .escape,
    ]

    if keysRequiringModifiers.contains(key) {
      return !shortcut.modifiers.isEmpty
    }

    return true
  }

  /// Checks if this combo conflicts with common system shortcuts
  var hasKnownSystemConflicts: Bool {
    let systemCombos: [KeyboardShortcuts.Shortcut] = [
      .init(.tab, modifiers: [.command]),  // App Switcher
      .init(.space, modifiers: [.command]),  // Spotlight
      .init(.q, modifiers: [.command]),  // Quit
      .init(.w, modifiers: [.command]),  // Close Window
      .init(.h, modifiers: [.command]),  // Hide App
    ]

    if shortcut == .init(.tab, modifiers: [.command]) {
      // Cmd+Tab is allowed when override explicitly enabled
      return !HotkeyOverrideState().isCmdTabEnabled
    }

    return systemCombos.contains(shortcut)
  }

  /// Alias for hasKnownSystemConflicts to match protocol expectations
  var hasSystemConflict: Bool {
    return hasKnownSystemConflicts
  }

  /// Validates if the key combination is valid
  var isValid: Bool {
    return isValidForGlobalHotkey
  }

  /// Gets the key code from the shortcut
  var keyCode: UInt16 {
    guard let key = shortcut.key else { return 49 }  // Default to space
    return keyCodeForKey(key)
  }

  /// Gets the modifier flags from the shortcut
  var modifiers: NSEvent.ModifierFlags {
    return shortcut.modifiers
  }

  /// Default KeyCombo factory methods to match protocol expectations
  static func defaultShowHide() -> KeyCombo {
    return .showHide
  }

  static func defaultSettings() -> KeyCombo {
    return .settings
  }

  static func defaultRefresh() -> KeyCombo {
    return .refresh
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func keyCodeForKey(_ key: KeyboardShortcuts.Key) -> UInt16 {
    switch key {
    case .space: return 49
    case .return: return 36
    case .escape: return 53
    case .delete: return 51
    case .tab: return 48
    case .a: return 0
    case .b: return 11
    case .c: return 8
    case .d: return 2
    case .e: return 14
    case .f: return 3
    case .g: return 5
    case .h: return 4
    case .i: return 34
    case .j: return 38
    case .k: return 40
    case .l: return 37
    case .m: return 46
    case .n: return 45
    case .o: return 31
    case .p: return 35
    case .q: return 12
    case .r: return 15
    case .s: return 1
    case .t: return 17
    case .u: return 32
    case .v: return 9
    case .w: return 13
    case .x: return 7
    case .y: return 16
    case .z: return 6
    case .zero: return 29
    case .one: return 18
    case .two: return 19
    case .three: return 20
    case .four: return 21
    case .five: return 23
    case .six: return 22
    case .seven: return 26
    case .eight: return 28
    case .nine: return 25
    case .comma: return 43
    case .period: return 47
    default: return 49  // Default to space
    }
  }
}

// MARK: - Codable Support
extension KeyCombo: Codable {
  enum CodingKeys: String, CodingKey {
    case key
    case modifiers
    case description
  }
  // swiftlint:disable:next cyclomatic_complexity
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let keyString = try container.decode(String.self, forKey: .key)
    let modifierStrings = try container.decode([String].self, forKey: .modifiers)
    let description = try container.decode(String.self, forKey: .description)

    // Convert key string to KeyboardShortcuts.Key
    let key: KeyboardShortcuts.Key
    switch keyString.lowercased() {
    case "space": key = .space
    case "return": key = .return
    case "tab": key = .tab
    case "escape": key = .escape
    case "comma": key = .comma
    case "a": key = .a
    case "b": key = .b
    case "c": key = .c
    case "d": key = .d
    case "e": key = .e
    case "f": key = .f
    case "g": key = .g
    case "h": key = .h
    case "i": key = .i
    case "j": key = .j
    case "k": key = .k
    case "l": key = .l
    case "m": key = .m
    case "n": key = .n
    case "o": key = .o
    case "p": key = .p
    case "q": key = .q
    case "r": key = .r
    case "s": key = .s
    case "t": key = .t
    case "u": key = .u
    case "v": key = .v
    case "w": key = .w
    case "x": key = .x
    case "y": key = .y
    case "z": key = .z
    default: key = .space
    }

    // Convert modifier strings to NSEvent.ModifierFlags
    var modifiers: NSEvent.ModifierFlags = []
    for modifierString in modifierStrings {
      switch modifierString.lowercased() {
      case "command": modifiers.insert(.command)
      case "shift": modifiers.insert(.shift)
      case "option": modifiers.insert(.option)
      case "control": modifiers.insert(.control)
      default: break
      }
    }

    let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    self.init(shortcut: shortcut, description: description)
  }
  // swiftlint:disable:next cyclomatic_complexity
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    // Encode key
    let keyString: String
    if let key = shortcut.key {
      switch key {
      case .space: keyString = "space"
      case .return: keyString = "return"
      case .tab: keyString = "tab"
      case .escape: keyString = "escape"
      case .comma: keyString = "comma"
      case .a: keyString = "a"
      case .b: keyString = "b"
      case .c: keyString = "c"
      case .d: keyString = "d"
      case .e: keyString = "e"
      case .f: keyString = "f"
      case .g: keyString = "g"
      case .h: keyString = "h"
      case .i: keyString = "i"
      case .j: keyString = "j"
      case .k: keyString = "k"
      case .l: keyString = "l"
      case .m: keyString = "m"
      case .n: keyString = "n"
      case .o: keyString = "o"
      case .p: keyString = "p"
      case .q: keyString = "q"
      case .r: keyString = "r"
      case .s: keyString = "s"
      case .t: keyString = "t"
      case .u: keyString = "u"
      case .v: keyString = "v"
      case .w: keyString = "w"
      case .x: keyString = "x"
      case .y: keyString = "y"
      case .z: keyString = "z"
      default: keyString = "space"
      }
    } else {
      keyString = "space"
    }

    // Encode modifiers
    var modifierStrings: [String] = []
    if shortcut.modifiers.contains(.command) { modifierStrings.append("command") }
    if shortcut.modifiers.contains(.shift) { modifierStrings.append("shift") }
    if shortcut.modifiers.contains(.option) { modifierStrings.append("option") }
    if shortcut.modifiers.contains(.control) { modifierStrings.append("control") }

    try container.encode(keyString, forKey: .key)
    try container.encode(modifierStrings, forKey: .modifiers)
    try container.encode(description, forKey: .description)
  }
}
