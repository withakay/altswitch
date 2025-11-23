//
//  ModifierDoubleTapDetectorTests.swift
//  AltSwitchTests
//

import CoreGraphics
import Foundation
import Testing

@Suite("ModifierDoubleTapDetector")
struct ModifierDoubleTapDetectorTests {

  @Test("Detects clean double tap within window")
  func detectsDoubleTap() async throws {
    let detector = ModifierDoubleTapDetector(tapWindow: 0.3)

    #expect(detector.noteModifierDown(.option, flags: [.maskAlternate], timestamp: 0.0) == false)
    #expect(detector.noteModifierDown(.option, flags: [.maskAlternate], timestamp: 0.2) == true)
  }

  @Test("Intervening keys force a new double tap sequence")
  func interveningKeyCancels() async throws {
    let detector = ModifierDoubleTapDetector(tapWindow: 0.3)

    _ = detector.noteModifierDown(.command, flags: [.maskCommand], timestamp: 0.0)
    detector.registerNonModifierKey()

    #expect(detector.noteModifierDown(.command, flags: [.maskCommand], timestamp: 0.1) == false)
    #expect(detector.noteModifierDown(.command, flags: [.maskCommand], timestamp: 0.25) == true)
  }

  @Test("Ignores presses when other modifiers are present")
  func ignoresMixedModifierPresses() async throws {
    let detector = ModifierDoubleTapDetector(tapWindow: 0.3)

    #expect(
      detector.noteModifierDown(
        .shift,
        flags: [.maskShift, .maskCommand],
        timestamp: 0.0
      ) == false
    )

    #expect(
      detector.noteModifierDown(
        .shift,
        flags: [.maskShift, .maskAlternate],
        timestamp: 0.15
      ) == false
    )
  }
}
