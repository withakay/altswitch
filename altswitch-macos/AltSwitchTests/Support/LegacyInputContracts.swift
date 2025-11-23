//
//  LegacyInputContracts.swift
//  AltSwitchTests
//
//  Test-only scaffolding to keep legacy contract suites compiling.
//

import AppKit
import Foundation

// MARK: - Keystroke Event

struct KeystrokeEvent {
  let character: String
  let keyCode: UInt16
  let modifierFlags: NSEvent.ModifierFlags
  let timestamp: Date
  let isPrintable: Bool
}

// MARK: - Protocols used by legacy tests

protocol KeystrokeHandlerProtocol: AnyObject {
  var onKeystroke: ((KeystrokeEvent) -> Void)? { get set }
  var isEnabled: Bool { get set }
  var handledKeystrokeCount: Int { get set }

  func setEnabled(_ enabled: Bool)
  func startMonitoring()
  func stopMonitoring()
  func handleKeystroke(_ event: NSEvent) -> Bool
  func shouldForwardToSearch(_ event: NSEvent) -> Bool
  func reset()
}

protocol FocusManagerProtocol: AnyObject {
  var isWindowVisible: Bool { get set }
  var isSearchFieldFocused: Bool { get set }
  var isTransitioningFocus: Bool { get set }
  var onFocusStateChange: ((Bool, Bool) -> Void)? { get set }
  var onFocusTransition: ((Bool) -> Void)? { get set }

  func showWindow()
  func hideWindow()
  func focusSearchField()
  func unfocusSearchField()
  func handleKeystroke(_ keystroke: KeystrokeEvent)
}

protocol SearchBoxIntegrationProtocol: AnyObject {
  var text: String { get }
  var isFocused: Bool { get }
  var isEmpty: Bool { get }
  var selectedRange: NSRange { get }

  var onTextChange: ((String) -> Void)? { get set }
  var onFocusChange: ((Bool) -> Void)? { get set }

  func setText(_ newText: String)
  func focus()
  func unfocus()
  func injectCharacter(_ character: String)
  func clearText()
  func deleteLastCharacter()
  func selectAll()
  func selectRange(location: Int, length: Int)
}

// MARK: - Convenience helpers for contract tests

extension KeystrokeHandlerProtocol {
  func isPrintableKeystroke(_ event: NSEvent) -> Bool {
    guard let chars = event.characters, !chars.isEmpty else { return false }
    let modifiers = event.modifierFlags.intersection([.command, .control, .option])
    return modifiers.isEmpty
  }

  func hasModifierKeys(_ event: NSEvent) -> Bool {
    return !event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty
  }
}
