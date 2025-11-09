//
//  TabOverrideEvent.swift
//  AltSwitch
//
//  Shared enums describing intercepted Cmd/Alt-Tab sequences.
//

import Foundation

enum TabCycleDirection: Sendable {
  case forward
  case backward
}

enum TabOverridePhase: Sendable {
  case began
  case repeated
  case ended(commit: Bool)
}

extension TabCycleDirection: CustomStringConvertible {
  var description: String {
    switch self {
    case .forward: return "forward"
    case .backward: return "backward"
    }
  }
}

extension TabOverridePhase: CustomStringConvertible {
  var description: String {
    switch self {
    case .began: return "began"
    case .repeated: return "repeated"
    case .ended(let commit): return "ended(commit: \(commit))"
    }
  }
}
