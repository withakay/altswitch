//
//  ModifierKey.swift
//  AltSwitch
//
//  Canonical list of modifier keys we track for gestures like double-tap activation.
//

import CoreGraphics
import Foundation

enum ModifierKey: String, CaseIterable, Identifiable, Sendable {
  case command
  case option
  case control
  case shift

  var id: String { rawValue }

  var cgFlag: CGEventFlags {
    switch self {
    case .command: return .maskCommand
    case .option: return .maskAlternate
    case .control: return .maskControl
    case .shift: return .maskShift
    }
  }

  var symbol: String {
    switch self {
    case .command: return "⌘"
    case .option: return "⌥"
    case .control: return "⌃"
    case .shift: return "⇧"
    }
  }

  var displayName: String {
    switch self {
    case .command: return "Command"
    case .option: return "Option"
    case .control: return "Control"
    case .shift: return "Shift"
    }
  }

  static let trackedMask: CGEventFlags = [
    .maskCommand,
    .maskAlternate,
    .maskControl,
    .maskShift,
  ]
}

extension CGEventFlags {
  /// Returns only the modifier flags we actively track.
  var trackedModifiersOnly: CGEventFlags {
    intersection(ModifierKey.trackedMask)
  }

  /// Whether the flags only contain the requested modifier (no other modifiers).
  func containsOnly(_ modifier: ModifierKey) -> Bool {
    trackedModifiersOnly == modifier.cgFlag
  }
}
