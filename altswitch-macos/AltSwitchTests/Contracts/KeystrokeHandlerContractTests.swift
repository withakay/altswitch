//
//  KeystrokeHandlerContractTests.swift
//  AltSwitchTests
//
//  Created by 002-when-the-main feature implementation.
//

import AppKit
import Testing

@testable import AltSwitch

@Suite("KeystrokeHandlerProtocol Contract Tests")
struct KeystrokeHandlerContractTests {

  @Test("Protocol requires isEnabled property")
  func protocolRequiresIsEnabledProperty() async throws {
    // This test ensures any KeystrokeHandlerProtocol implementation
    // provides the isEnabled property
    let handler = MockKeystrokeHandler()
    #expect(handler.isEnabled == false)
  }

  @Test("Protocol requires handledKeystrokeCount property")
  func protocolRequiresHandledKeystrokeCountProperty() async throws {
    let handler = MockKeystrokeHandler()
    #expect(handler.handledKeystrokeCount == 0)
  }

  @Test("Protocol requires setEnabled method")
  func protocolRequiresSetEnabledMethod() async throws {
    let handler = MockKeystrokeHandler()
    handler.setEnabled(true)
    #expect(handler.isEnabled == true)

    handler.setEnabled(false)
    #expect(handler.isEnabled == false)
  }

  @Test("Protocol requires handleKeystroke method")
  func protocolRequiresHandleKeystrokeMethod() async throws {
    let handler = MockKeystrokeHandler()
    let event = createTestKeyEvent(character: "a")

    let result = handler.handleKeystroke(event)
    #expect(result == false)  // Default mock implementation
  }

  @Test("Protocol requires shouldForwardToSearch method")
  func protocolRequiresShouldForwardToSearchMethod() async throws {
    let handler = MockKeystrokeHandler()
    let event = createTestKeyEvent(character: "a")

    let result = handler.shouldForwardToSearch(event)
    #expect(result == false)  // Default mock implementation
  }

  @Test("Protocol requires reset method")
  func protocolRequiresResetMethod() async throws {
    let handler = MockKeystrokeHandler()
    handler.setEnabled(true)
    handler.handledKeystrokeCount = 5

    handler.reset()
    #expect(handler.isEnabled == false)
    #expect(handler.handledKeystrokeCount == 0)
  }

  @Test("Protocol extension provides isPrintableKeystroke method")
  func protocolExtensionProvidesIsPrintableKeystroke() async throws {
    let handler = MockKeystrokeHandler()

    // Test printable character
    let printableEvent = createTestKeyEvent(character: "a")
    #expect(handler.isPrintableKeystroke(printableEvent) == true)

    // Test non-printable (modifier key)
    let modifierEvent = createTestKeyEvent(character: "", keyCode: 55)  // Command key
    #expect(handler.isPrintableKeystroke(modifierEvent) == false)
  }

  @Test("Protocol extension provides hasModifierKeys method")
  func protocolExtensionProvidesHasModifierKeys() async throws {
    let handler = MockKeystrokeHandler()

    // Test with no modifiers
    let noModifiersEvent = createTestKeyEvent(character: "a", modifiers: [])
    #expect(handler.hasModifierKeys(noModifiersEvent) == false)

    // Test with command modifier
    let commandEvent = createTestKeyEvent(character: "a", modifiers: [.command])
    #expect(handler.hasModifierKeys(commandEvent) == true)

    // Test with multiple modifiers
    let multiEvent = createTestKeyEvent(character: "a", modifiers: [.command, .shift])
    #expect(handler.hasModifierKeys(multiEvent) == true)
  }

  // MARK: - Helper Methods

  private func createTestKeyEvent(
    character: String,
    keyCode: UInt16 = 0,
    modifiers: NSEvent.ModifierFlags = []
  ) -> NSEvent {
    return NSEvent.keyEvent(
      with: .keyDown,
      location: NSPoint(x: 0, y: 0),
      modifierFlags: modifiers,
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: character,
      charactersIgnoringModifiers: character,
      isARepeat: false,
      keyCode: keyCode
    )!
  }
}

// Mock implementation for testing protocol compliance
private class MockKeystrokeHandler: KeystrokeHandlerProtocol {
  var isEnabled: Bool = false
  var handledKeystrokeCount: Int = 0

  func setEnabled(_ enabled: Bool) {
    isEnabled = enabled
  }

  func handleKeystroke(_ event: NSEvent) -> Bool {
    handledKeystrokeCount += 1
    return false
  }

  func shouldForwardToSearch(_ event: NSEvent) -> Bool {
    return false
  }

  func reset() {
    isEnabled = false
    handledKeystrokeCount = 0
  }
}
