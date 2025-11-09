//
//  WindowAppearance.swift
//  AltSwitch
//
//  Model for window appearance configuration and validation
//  Supports modern macOS visual design requirements with proper validation
//

import AppKit
import Foundation

@Observable
final class WindowAppearance: Codable, @unchecked Sendable {
  let cornerRadius: CGFloat
  let hasShadow: Bool
  let isMovableByBackground: Bool

  // MARK: - Initializers

  init(
    cornerRadius: CGFloat = 16.0,
    hasShadow: Bool = true,
    isMovableByBackground: Bool = true
  ) {
    // Clamp values to valid ranges during initialization
    self.cornerRadius = max(0.0, min(32.0, cornerRadius))
    self.hasShadow = hasShadow
    self.isMovableByBackground = isMovableByBackground
  }

  // MARK: - Validation Properties

  var isValid: Bool {
    return cornerRadius >= 0.0 && cornerRadius <= 32.0 && !cornerRadius.isNaN
      && !cornerRadius.isInfinite
  }

  var usesContinuousCurve: Bool {
    // macOS 11+ supports continuous curves
    if #available(macOS 11.0, *) {
      return true
    }
    return false
  }

  var isConsistent: Bool {
    // All valid configurations are considered consistent in our design
    return isValid
  }

  var validationErrors: [String] {
    var errors: [String] = []

    if cornerRadius < 0 {
      errors.append("Corner radius cannot be negative")
    }
    if cornerRadius > 32 {
      errors.append("Corner radius exceeds maximum of 32 pixels")
    }
    if cornerRadius.isNaN {
      errors.append("Corner radius cannot be NaN")
    }
    if cornerRadius.isInfinite {
      errors.append("Corner radius cannot be infinite")
    }

    return errors
  }

  var isCompatibleWithMacOS11Plus: Bool {
    if #available(macOS 11.0, *) {
      return true
    }
    return false
  }

  // MARK: - Factory Methods

  static func `default`() -> WindowAppearance {
    return WindowAppearance(
      cornerRadius: 16.0,
      hasShadow: true,
      isMovableByBackground: true
    )
  }

  static func minimal() -> WindowAppearance {
    return WindowAppearance(
      cornerRadius: 8.0,
      hasShadow: false,
      isMovableByBackground: true
    )
  }

  static func prominent() -> WindowAppearance {
    return WindowAppearance(
      cornerRadius: 24.0,
      hasShadow: true,
      isMovableByBackground: true
    )
  }
}

// MARK: - Identifiable
extension WindowAppearance: Identifiable {
  var id: String {
    return "\(cornerRadius)-\(hasShadow)-\(isMovableByBackground)"
  }
}

// MARK: - Equatable
extension WindowAppearance: Equatable {
  static func == (lhs: WindowAppearance, rhs: WindowAppearance) -> Bool {
    return lhs.cornerRadius == rhs.cornerRadius && lhs.hasShadow == rhs.hasShadow
      && lhs.isMovableByBackground == rhs.isMovableByBackground
  }
}

// MARK: - Hashable
extension WindowAppearance: Hashable {
  func hash(into hasher: inout Hasher) {
    hasher.combine(cornerRadius)
    hasher.combine(hasShadow)
    hasher.combine(isMovableByBackground)
  }
}

// MARK: - Codable
extension WindowAppearance {
  enum CodingKeys: String, CodingKey {
    case cornerRadius
    case hasShadow
    case isMovableByBackground
  }

  convenience init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let cornerRadius = try container.decode(CGFloat.self, forKey: .cornerRadius)
    let hasShadow = try container.decode(Bool.self, forKey: .hasShadow)
    let isMovableByBackground = try container.decode(Bool.self, forKey: .isMovableByBackground)

    self.init(
      cornerRadius: cornerRadius,
      hasShadow: hasShadow,
      isMovableByBackground: isMovableByBackground
    )
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(cornerRadius, forKey: .cornerRadius)
    try container.encode(hasShadow, forKey: .hasShadow)
    try container.encode(isMovableByBackground, forKey: .isMovableByBackground)
  }
}

// MARK: - Preview Support
extension WindowAppearance {
  static var preview: WindowAppearance {
    return .default()
  }

  static var previewMinimal: WindowAppearance {
    return .minimal()
  }

  static var previewProminent: WindowAppearance {
    return .prominent()
  }
}
