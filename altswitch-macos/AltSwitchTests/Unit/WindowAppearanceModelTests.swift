//
//  ModifierKeyFlagTests.swift
//  AltSwitchTests
//

import CoreGraphics
import Testing

@testable import AltSwitch

@Suite("ModifierKey flags")
struct ModifierKeyFlagTests {

  @Test("containsOnly respects single modifier")
  func containsOnlySingleModifier() {
    #expect(CGEventFlags.maskCommand.containsOnly(.command))
    #expect(!CGEventFlags([.maskCommand, .maskShift]).containsOnly(.command))
    #expect(!CGEventFlags.maskAlternate.containsOnly(.command))
  }

  @Test("trackedModifiersOnly strips unrelated flags")
  func stripsUntrackedFlags() {
    let flags: CGEventFlags = [.maskControl, .maskSecondaryFn, .maskHelp, .maskShift]
    #expect(flags.trackedModifiersOnly == [.maskControl, .maskShift])
  }
}
