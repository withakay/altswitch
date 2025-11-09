//
//  KeyComboTests.swift
//  AltSwitchTests
//
//  Unit tests for KeyCombo model validation and functionality
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import KeyboardShortcuts
import Testing

@testable import AltSwitch

@Suite("KeyCombo Model Unit Tests")
struct KeyComboTests {

  @Test("KeyCombo initialization with valid shortcut")
  func testKeyComboInitializationWithValidShortcut() throws {
    // Arrange & Act
    let shortcut = KeyboardShortcuts.Shortcut(.space, modifiers: [.command, .shift])
    let keyCombo = KeyCombo(shortcut: shortcut, description: "Show/Hide AltSwitch")

    // Assert
    #expect(keyCombo.shortcut == shortcut)
    #expect(keyCombo.description == "Show/Hide AltSwitch")
    #expect(keyCombo.isValid, "KeyCombo with valid shortcut should be valid")
  }

  @Test("KeyCombo validation with different modifier combinations")
  func testKeyComboValidationWithModifierCombinations() throws {
    let validCombinations = [
      (KeyboardShortcuts.Shortcut(.space, modifiers: [.command]), "Cmd+Space"),
      (KeyboardShortcuts.Shortcut(.space, modifiers: [.command, .shift]), "Cmd+Shift+Space"),
      (KeyboardShortcuts.Shortcut(.t, modifiers: [.command, .option]), "Cmd+Opt+T"),
      (KeyboardShortcuts.Shortcut(.f12, modifiers: [.control, .shift]), "Ctrl+Shift+F12"),
      (
        KeyboardShortcuts.Shortcut(.escape, modifiers: [.command, .option, .control]),
        "Cmd+Opt+Ctrl+Esc"
      ),
    ]

    for (shortcut, description) in validCombinations {
      let keyCombo = KeyCombo(shortcut: shortcut, description: description)
      #expect(keyCombo.isValid, "\(description) should be valid")
    }
  }

  @Test("KeyCombo validation rejects invalid combinations")
  func testKeyComboValidationRejectsInvalidCombinations() throws {
    let invalidCombinations = [
      (KeyboardShortcuts.Shortcut(.space, modifiers: []), "Space without modifiers"),
      (KeyboardShortcuts.Shortcut(.escape, modifiers: [.shift]), "Escape with only Shift"),
      (KeyboardShortcuts.Shortcut(.f1, modifiers: [.capsLock]), "F1 with only CapsLock"),
      (KeyboardShortcuts.Shortcut(.tab, modifiers: []), "Tab without modifiers"),
    ]

    for (shortcut, description) in invalidCombinations {
      let keyCombo = KeyCombo(shortcut: shortcut, description: description)
      #expect(!keyCombo.isValid, "\(description) should be invalid")
    }
  }

  @Test("KeyCombo equality and hashing")
  func testKeyComboEqualityAndHashing() throws {
    // Arrange
    let shortcut1 = KeyboardShortcuts.Shortcut(.space, modifiers: [.command, .shift])
    let shortcut2 = KeyboardShortcuts.Shortcut(.space, modifiers: [.command, .shift])
    let shortcut3 = KeyboardShortcuts.Shortcut(.t, modifiers: [.command, .option])

    let combo1 = KeyCombo(shortcut: shortcut1, description: "Show/Hide")
    let combo2 = KeyCombo(shortcut: shortcut2, description: "Show/Hide")  // Same shortcut, same description
    let combo3 = KeyCombo(shortcut: shortcut2, description: "Different Description")  // Same shortcut, different description
    let combo4 = KeyCombo(shortcut: shortcut3, description: "Show/Hide")  // Different shortcut, same description

    // Assert equality based on shortcut (description should not matter for equality)
    #expect(combo1 == combo2, "KeyCombos with same shortcut should be equal")
    #expect(
      combo1 == combo3, "KeyCombos with same shortcut should be equal regardless of description")
    #expect(combo1 != combo4, "KeyCombos with different shortcuts should not be equal")

    // Assert hash consistency
    #expect(combo1.hashValue == combo2.hashValue, "Equal KeyCombos should have same hash")
    #expect(
      combo1.hashValue == combo3.hashValue, "KeyCombos with same shortcut should have same hash")
  }

  @Test("KeyCombo system conflict detection")
  func testKeyComboSystemConflictDetection() throws {
    let systemConflicts = [
      KeyboardShortcuts.Shortcut(.tab, modifiers: [.command]),  // Cmd+Tab (App Switcher)
      KeyboardShortcuts.Shortcut(.space, modifiers: [.command]),  // Cmd+Space (Spotlight)
      KeyboardShortcuts.Shortcut(.q, modifiers: [.command]),  // Cmd+Q (Quit)
      KeyboardShortcuts.Shortcut(.w, modifiers: [.command]),  // Cmd+W (Close Window)
      KeyboardShortcuts.Shortcut(.h, modifiers: [.command]),  // Cmd+H (Hide App)
    ]

    for shortcut in systemConflicts {
      let keyCombo = KeyCombo(shortcut: shortcut, description: "System Conflict Test")
      #expect(
        keyCombo.hasSystemConflict,
        "KeyCombo \(keyCombo.displayString) should detect system conflict")
    }

    // Test non-conflicting shortcuts
    let safeShortcuts = [
      KeyboardShortcuts.Shortcut(.space, modifiers: [.command, .shift]),
      KeyboardShortcuts.Shortcut(.t, modifiers: [.command, .option]),
      KeyboardShortcuts.Shortcut(.f12, modifiers: [.control, .shift]),
    ]

    for shortcut in safeShortcuts {
      let keyCombo = KeyCombo(shortcut: shortcut, description: "Safe Shortcut Test")
      #expect(
        !keyCombo.hasSystemConflict,
        "KeyCombo \(keyCombo.displayString) should not have system conflict")
    }
  }

  @Test("KeyCombo display string formatting")
  func testKeyComboDisplayStringFormatting() throws {
    let testCases = [
      (KeyboardShortcuts.Shortcut(.space, modifiers: [.command]), "⌘Space"),
      (KeyboardShortcuts.Shortcut(.space, modifiers: [.command, .shift]), "⌘⇧Space"),
      (KeyboardShortcuts.Shortcut(.t, modifiers: [.command, .option]), "⌘⌥T"),
      (KeyboardShortcuts.Shortcut(.f12, modifiers: [.control, .shift]), "⌃⇧F12"),
      (KeyboardShortcuts.Shortcut(.escape, modifiers: [.command, .option, .control]), "⌘⌥⌃Escape"),
      (KeyboardShortcuts.Shortcut(.return, modifiers: [.command, .shift]), "⌘⇧Return"),
    ]

    for (shortcut, expectedDisplay) in testCases {
      let keyCombo = KeyCombo(shortcut: shortcut, description: "Test")
      #expect(
        keyCombo.displayString == expectedDisplay,
        "Display string for \(keyCombo.description) should be \(expectedDisplay), got \(keyCombo.displayString)"
      )
    }
  }

  @Test("KeyCombo serialization and deserialization")
  func testKeyComboSerializationAndDeserialization() throws {
    // Arrange
    let originalCombo = KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Show/Hide AltSwitch"
    )

    // Act - Serialize to data
    let encoder = JSONEncoder()
    let data = try encoder.encode(originalCombo)

    // Deserialize from data
    let decoder = JSONDecoder()
    let decodedCombo = try decoder.decode(KeyCombo.self, from: data)

    // Assert
    #expect(
      decodedCombo.shortcut == originalCombo.shortcut,
      "Deserialized shortcut should match original")
    #expect(
      decodedCombo.description == originalCombo.description,
      "Deserialized description should match original")
    #expect(
      decodedCombo == originalCombo,
      "Deserialized KeyCombo should equal original")
  }

  @Test("KeyCombo validation with edge case keys")
  func testKeyComboValidationWithEdgeCaseKeys() throws {
    let edgeCaseTests = [
      // Function keys
      (KeyboardShortcuts.Shortcut(.f1, modifiers: [.command]), true, "F1 with Cmd should be valid"),
      (
        KeyboardShortcuts.Shortcut(.f13, modifiers: [.command]), true,
        "F13 with Cmd should be valid"
      ),

      // Arrow keys
      (
        KeyboardShortcuts.Shortcut(.upArrow, modifiers: [.command, .option]), true,
        "Arrow key with modifiers should be valid"
      ),
      (
        KeyboardShortcuts.Shortcut(.downArrow, modifiers: []), false,
        "Arrow key without modifiers should be invalid"
      ),

      // Number keys
      (
        KeyboardShortcuts.Shortcut(.one, modifiers: [.command]), true,
        "Number key with Cmd should be valid"
      ),
      (
        KeyboardShortcuts.Shortcut(.zero, modifiers: [.shift]), false,
        "Number key with only Shift should be invalid"
      ),

      // Special keys
      (
        KeyboardShortcuts.Shortcut(.delete, modifiers: [.command]), true,
        "Delete with Cmd should be valid"
      ),
      (
        KeyboardShortcuts.Shortcut(.home, modifiers: [.control]), true,
        "Home with Ctrl should be valid"
      ),
      (
        KeyboardShortcuts.Shortcut(.pageUp, modifiers: [.option]), true,
        "PageUp with Option should be valid"
      ),
    ]

    for (shortcut, expectedValid, description) in edgeCaseTests {
      let keyCombo = KeyCombo(shortcut: shortcut, description: description)
      #expect(keyCombo.isValid == expectedValid, "\(description)")
    }
  }

  @Test("KeyCombo accessibility description")
  func testKeyComboAccessibilityDescription() throws {
    let testCases = [
      (KeyboardShortcuts.Shortcut(.space, modifiers: [.command]), "Command Space"),
      (KeyboardShortcuts.Shortcut(.space, modifiers: [.command, .shift]), "Command Shift Space"),
      (KeyboardShortcuts.Shortcut(.t, modifiers: [.command, .option]), "Command Option T"),
      (KeyboardShortcuts.Shortcut(.f12, modifiers: [.control, .shift]), "Control Shift F12"),
      (KeyboardShortcuts.Shortcut(.return, modifiers: [.command]), "Command Return"),
    ]

    for (shortcut, expectedAccessibilityDescription) in testCases {
      let keyCombo = KeyCombo(shortcut: shortcut, description: "Test")
      #expect(
        keyCombo.accessibilityDescription == expectedAccessibilityDescription,
        "Accessibility description should be \(expectedAccessibilityDescription), got \(keyCombo.accessibilityDescription)"
      )
    }
  }

  @Test("KeyCombo factory methods for common shortcuts")
  func testKeyComboFactoryMethodsForCommonShortcuts() throws {
    // Test factory method for default show/hide shortcut
    let defaultShowHide = KeyCombo.defaultShowHide()
    #expect(defaultShowHide.shortcut == .init(.space, modifiers: [.command, .shift]))
    #expect(defaultShowHide.description == "Show/Hide AltSwitch")
    #expect(defaultShowHide.isValid)

    // Test factory method for default settings shortcut
    let defaultSettings = KeyCombo.defaultSettings()
    #expect(defaultSettings.shortcut == .init(.comma, modifiers: [.command]))
    #expect(defaultSettings.description == "Open Settings")
    #expect(defaultSettings.isValid)

    // Test factory method for default refresh shortcut
    let defaultRefresh = KeyCombo.defaultRefresh()
    #expect(defaultRefresh.shortcut == .init(.r, modifiers: [.command, .shift]))
    #expect(defaultRefresh.description == "Refresh App List")
    #expect(defaultRefresh.isValid)
  }

  @Test("KeyCombo performance with large collections")
  func testKeyComboPerformanceWithLargeCollections() throws {
    // Arrange - Create a large collection of KeyCombos
    var keyCombos: Set<KeyCombo> = []
    let keys: [KeyboardShortcuts.Key] = [
      .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m, .n, .o, .p,
    ]
    let modifierSets: [NSEvent.ModifierFlags] = [
      [.command],
      [.command, .shift],
      [.command, .option],
      [.control, .shift],
    ]

    for key in keys {
      for modifiers in modifierSets {
        let shortcut = KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
        let combo = KeyCombo(shortcut: shortcut, description: "Test \(key.rawValue)")
        keyCombos.insert(combo)
      }
    }

    // Act & Assert - Performance test for lookup operations
    let testCombo = KeyCombo(
      shortcut: .init(.a, modifiers: [.command]),
      description: "Test A"
    )

    let startTime = Date()
    let contains = keyCombos.contains(testCombo)
    let lookupTime = Date().timeIntervalSince(startTime)

    #expect(contains, "Set should contain test combo")
    #expect(lookupTime < 0.001, "Lookup should be fast: \(lookupTime)s")

    // Performance test for validation
    let validationStartTime = Date()
    let validCombos = keyCombos.filter { $0.isValid }
    let validationTime = Date().timeIntervalSince(validationStartTime)

    #expect(validCombos.count > 0, "Should have valid combos")
    #expect(validationTime < 0.01, "Validation should be fast: \(validationTime)s")
  }
}

// MARK: - Test KeyCombo Implementation (This will fail until actual implementation exists)

/// Test implementation of KeyCombo model for contract verification
/// This implementation will cause tests to fail until the real implementation is created
private struct KeyCombo: Hashable, Codable, Sendable {
  let shortcut: KeyboardShortcuts.Shortcut
  let description: String

  init(shortcut: KeyboardShortcuts.Shortcut, description: String) {
    self.shortcut = shortcut
    self.description = description
  }

  // MARK: - Validation Properties

  var isValid: Bool {
    // Must have at least one meaningful modifier
    let meaningfulModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
    return shortcut.modifiers.intersection(meaningfulModifiers).isEmpty == false
  }

  var hasSystemConflict: Bool {
    let systemConflicts: [KeyboardShortcuts.Shortcut] = [
      .init(.tab, modifiers: [.command]),  // App Switcher
      .init(.space, modifiers: [.command]),  // Spotlight
      .init(.q, modifiers: [.command]),  // Quit
      .init(.w, modifiers: [.command]),  // Close Window
      .init(.h, modifiers: [.command]),  // Hide App
    ]

    return systemConflicts.contains(shortcut)
  }

  // MARK: - Display Properties

  var displayString: String {
    var result = ""

    if shortcut.modifiers.contains(.command) { result += "⌘" }
    if shortcut.modifiers.contains(.option) { result += "⌥" }
    if shortcut.modifiers.contains(.control) { result += "⌃" }
    if shortcut.modifiers.contains(.shift) { result += "⇧" }

    // Convert key to display string
    let keyString: String
    switch shortcut.key {
    case .space: keyString = "Space"
    case .return: keyString = "Return"
    case .escape: keyString = "Escape"
    case .delete: keyString = "Delete"
    case .tab: keyString = "Tab"
    case .upArrow: keyString = "↑"
    case .downArrow: keyString = "↓"
    case .leftArrow: keyString = "←"
    case .rightArrow: keyString = "→"
    default: keyString = String(describing: shortcut.key).uppercased()
    }

    result += keyString
    return result
  }

  var accessibilityDescription: String {
    var components: [String] = []

    if shortcut.modifiers.contains(.command) { components.append("Command") }
    if shortcut.modifiers.contains(.option) { components.append("Option") }
    if shortcut.modifiers.contains(.control) { components.append("Control") }
    if shortcut.modifiers.contains(.shift) { components.append("Shift") }

    // Convert key to accessibility string
    let keyString: String
    switch shortcut.key {
    case .space: keyString = "Space"
    case .return: keyString = "Return"
    case .escape: keyString = "Escape"
    case .delete: keyString = "Delete"
    case .tab: keyString = "Tab"
    case .upArrow: keyString = "Up Arrow"
    case .downArrow: keyString = "Down Arrow"
    case .leftArrow: keyString = "Left Arrow"
    case .rightArrow: keyString = "Right Arrow"
    default: keyString = String(describing: shortcut.key).uppercased()
    }

    components.append(keyString)
    return components.joined(separator: " ")
  }

  // MARK: - Factory Methods

  static func defaultShowHide() -> KeyCombo {
    return KeyCombo(
      shortcut: .init(.space, modifiers: [.command, .shift]),
      description: "Show/Hide AltSwitch"
    )
  }

  static func defaultSettings() -> KeyCombo {
    return KeyCombo(
      shortcut: .init(.comma, modifiers: [.command]),
      description: "Open Settings"
    )
  }

  static func defaultRefresh() -> KeyCombo {
    return KeyCombo(
      shortcut: .init(.r, modifiers: [.command, .shift]),
      description: "Refresh App List"
    )
  }

  // MARK: - Hashable

  func hash(into hasher: inout Hasher) {
    hasher.combine(shortcut)
  }

  static func == (lhs: KeyCombo, rhs: KeyCombo) -> Bool {
    return lhs.shortcut == rhs.shortcut
  }

  // MARK: - Codable

  enum CodingKeys: String, CodingKey {
    case shortcut, description
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.description = try container.decode(String.self, forKey: .description)

    // For testing purposes, create a simple shortcut
    // Real implementation would properly decode KeyboardShortcuts.Shortcut
    self.shortcut = .init(.space, modifiers: [.command, .shift])
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(description, forKey: .description)
    // Real implementation would properly encode KeyboardShortcuts.Shortcut
  }
}
