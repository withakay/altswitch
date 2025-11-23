//
//  ModifierDoubleTapDetectorResetTests.swift
//  AltSwitchTests
//

import CoreGraphics
import Testing

@testable import AltSwitch

@Suite("ModifierDoubleTapDetector reset behavior")
struct ModifierDoubleTapDetectorResetTests {

  @Test("Clears state when switching modifiers")
  func resetWhenModifierChanges() {
    let detector = ModifierDoubleTapDetector(tapWindow: 0.3)

    // First tap command, then switch to option which should not inherit state
    _ = detector.noteModifierDown(.command, flags: [.maskCommand], timestamp: 0.0)
    let triggered = detector.noteModifierDown(.option, flags: [.maskAlternate], timestamp: 0.15)

    #expect(triggered == false)
  }

  @Test("Resets when explicitly requested")
  func explicitResetClearsHistory() {
    let detector = ModifierDoubleTapDetector(tapWindow: 0.3)

    _ = detector.noteModifierDown(.shift, flags: [.maskShift], timestamp: 0.0)
    detector.reset()
    let triggered = detector.noteModifierDown(.shift, flags: [.maskShift], timestamp: 0.2)

    #expect(triggered == false)
  }
}
