//
//  HotkeyOverrideStateTests.swift
//  AltSwitchTests
//

import Foundation
import Testing

@testable import AltSwitch

@Suite("HotkeyOverrideState")
struct HotkeyOverrideStateTests {

  @Test("Maps double-tap modes to modifiers")
  func mapsDoubleTapModes() {
    #expect(HotkeyMode.doubleTapOption.doubleTapModifier == .option)
    #expect(HotkeyMode.doubleTapCommand.doubleTapModifier == .command)
    #expect(HotkeyMode.doubleTapControl.doubleTapModifier == .control)
    #expect(HotkeyMode.doubleTapShift.doubleTapModifier == .shift)
    #expect(HotkeyMode.custom.doubleTapModifier == nil)
  }

  @Test("Persists mode and override flags")
  func persistsSelections() {
    let suiteName = "HotkeyOverrideStateTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      Issue.record("Failed to create isolated UserDefaults suite")
      return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    var state = HotkeyOverrideState(defaults: defaults)
    #expect(state.mode == .custom)
    #expect(state.isAltTabEnabled == false)
    #expect(state.isCmdTabEnabled == false)

    state.mode = .doubleTapCommand
    state.isAltTabEnabled = true
    state.isCmdTabEnabled = true

    let reloaded = HotkeyOverrideState(defaults: defaults)
    #expect(reloaded.mode == .doubleTapCommand)
    #expect(reloaded.isAltTabEnabled)
    #expect(reloaded.isCmdTabEnabled)
    #expect(reloaded.doubleTapModifier == .command)
  }
}
