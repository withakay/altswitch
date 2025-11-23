//
//  KeyComboTests.swift
//  AltSwitchTests
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

@Suite("KeyCombo")
struct KeyComboTests {

  @Test("Produces symbol-rich display string")
  func displayStringFormatsWithSymbols() {
    let combo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Show/Hide AltSwitch"
    )

    #expect(combo.displayString == "⌘⇧Space")
  }

  @Test("Builds accessibility-friendly description")
  func accessibilityDescriptionIsReadable() {
    let combo = KeyCombo(
      shortcut: .init(.return, modifiers: [.command, .option, .control]),
      description: "Test"
    )

    #expect(combo.accessibilityDescription == "Command Option Control Return")
  }

  @Test("Detects common system conflicts")
  func detectsSystemConflicts() {
    let spotlight = KeyCombo(
      shortcut: .init(.space, modifiers: [.command]),
      description: "Spotlight"
    )
    let benign = KeyCombo(
      shortcut: .init(.k, modifiers: [.command, .shift]),
      description: "Unused"
    )

    #expect(spotlight.hasKnownSystemConflicts)
    #expect(!benign.hasKnownSystemConflicts)
  }

  @Test("Validates default combos")
  func validatesDefaults() {
    #expect(KeyCombo.showHide.isValidForGlobalHotkey)
    #expect(KeyCombo.settings.isValidForGlobalHotkey)
    #expect(KeyCombo.refresh.isValidForGlobalHotkey)
  }

  @Test("Returns expected key codes")
  func keyCodesMatchExpectedValues() {
    let combos: [(KeyboardShortcuts.Key, UInt16)] = [
      (.space, 49),
      (.return, 36),
      (.escape, 53),
      (.tab, 48),
    ]

    for (key, expectedCode) in combos {
      let combo = KeyCombo(shortcut: .init(key, modifiers: [.command]))
      #expect(combo.keyCode == expectedCode, "Key code for \(key) should be \(expectedCode)")
    }
  }
}
