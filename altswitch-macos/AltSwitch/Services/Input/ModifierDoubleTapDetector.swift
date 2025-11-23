//
//  ModifierDoubleTapDetector.swift
//  AltSwitch
//
//  Detects rapid double-taps of modifier keys using CGEvent flags.
//

import CoreGraphics
import Foundation

/// Stateless-ish helper to detect double-tap gestures on modifier keys.
final class ModifierDoubleTapDetector {
  static let defaultTapWindow: CFTimeInterval = 0.35
  private var lastTapTimes: [ModifierKey: CFAbsoluteTime] = [:]
  private var sawInterveningNonModifierKey = false
  private let tapWindow: CFTimeInterval
  var onReset: (() -> Void)?

  init(tapWindow: CFTimeInterval = ModifierDoubleTapDetector.defaultTapWindow) {
    self.tapWindow = max(0.1, tapWindow)
  }

  /// Marks that a non-modifier key was pressed, which cancels any in-flight tap sequence.
  func registerNonModifierKey() {
    sawInterveningNonModifierKey = true
  }

  /// Returns true when a double-tap for the modifier is detected.
  func noteModifierDown(
    _ modifier: ModifierKey,
    flags: CGEventFlags,
    timestamp: CFTimeInterval = CFAbsoluteTimeGetCurrent()
  ) -> Bool {
    // Only count clean taps of the single modifier with no other modifiers mixed in.
    guard flags.containsOnly(modifier) else {
      reset(for: modifier)
      return false
    }

    let lastTap = lastTapTimes[modifier]
    lastTapTimes[modifier] = timestamp

    defer { sawInterveningNonModifierKey = false }

    guard let lastTap else { return false }
    guard !sawInterveningNonModifierKey else { return false }

    return (timestamp - lastTap) <= tapWindow
  }

  func reset(for modifier: ModifierKey? = nil) {
    if let modifier {
      lastTapTimes.removeValue(forKey: modifier)
    } else {
      lastTapTimes.removeAll()
    }
    sawInterveningNonModifierKey = false
    onReset?()
  }
}
