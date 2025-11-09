import XCTest

@testable import AltSwitch

/// Integration tests for modifier key preservation
///
/// Requirements from quickstart.md:
/// - Existing keyboard shortcuts must be preserved
/// - Command, Control, Option, Shift combinations should not be forwarded
/// - System shortcuts should continue to work normally
/// - Only unmodified printable characters should be forwarded
final class ModifierKeyTests: XCTestCase {

  // MARK: - Test Properties

  private var keystrokeHandler: any KeystrokeHandlerProtocol!
  private var focusManager: any FocusManagerProtocol!
  private var searchBox: any SearchBoxIntegrationProtocol!
  private var mainWindow: MainWindow!
  private var interceptedSystemEvents: [NSEvent] = []

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()
    setupTestComponents()
    interceptedSystemEvents = []
  }

  override func tearDown() {
    teardownTestComponents()
    super.tearDown()
  }

  // MARK: - Factory Methods

  /// Creates test components for integration testing
  /// Implementations must override these to return their instances
  func createKeystrokeHandler() -> any KeystrokeHandlerProtocol {
    fatalError("Subclasses must implement createKeystrokeHandler()")
  }

  func createFocusManager() -> any FocusManagerProtocol {
    fatalError("Subclasses must implement createFocusManager()")
  }

  func createSearchBox() -> any SearchBoxIntegrationProtocol {
    fatalError("Subclasses must implement createSearchBox()")
  }

  func createMainWindow() -> MainWindow {
    fatalError("Subclasses must implement createMainWindow()")
  }

  // MARK: - Integration Tests

  // MARK: Command Key Combinations

  func testCommandKeyCombinations_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()
    XCTAssertTrue(mainWindow.isVisible)
    XCTAssertEqual(searchBox.text, "")

    // When: User types Command+C (copy)
    simulateKeystroke("c", modifiers: [.command])

    // Then: Character should not appear in search box
    XCTAssertEqual(searchBox.text, "", "Command+C should not be forwarded to search box")
    XCTAssertFalse(searchBox.isFocused, "Search box should not be focused for Command+C")
  }

  func testCommandKeyCombinations_SystemShortcuts_Preserved() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types various Command combinations
    simulateKeystroke("c", modifiers: [.command])  // Copy
    simulateKeystroke("v", modifiers: [.command])  // Paste
    simulateKeystroke("x", modifiers: [.command])  // Cut
    simulateKeystroke("z", modifiers: [.command])  // Undo
    simulateKeystroke("a", modifiers: [.command])  // Select All

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Command combinations should not be forwarded")
    XCTAssertFalse(searchBox.isFocused, "Search box should not be focused for Command combinations")
  }

  func testCommandKeyCombinations_WithShift_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types Command+Shift combinations
    simulateKeystroke("c", modifiers: [.command, .shift])  // Command+Shift+C
    simulateKeystroke("3", modifiers: [.command, .shift])  // Command+Shift+3 (screenshot)

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Command+Shift combinations should not be forwarded")
    XCTAssertFalse(
      searchBox.isFocused, "Search box should not be focused for Command+Shift combinations")
  }

  // MARK: Control Key Combinations

  func testControlKeyCombinations_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types Control combinations
    simulateKeystroke("c", modifiers: [.control])  // Control+C
    simulateKeystroke("f", modifiers: [.control])  // Control+F

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Control combinations should not be forwarded")
    XCTAssertFalse(searchBox.isFocused, "Search box should not be focused for Control combinations")
  }

  func testControlKeyCombinations_CommonShortcuts_Preserved() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types common Control combinations
    simulateKeystroke("a", modifiers: [.control])  // Control+A (beginning of line)
    simulateKeystroke("e", modifiers: [.control])  // Control+E (end of line)
    simulateKeystroke("k", modifiers: [.control])  // Control+K (delete to end of line)

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Control combinations should not be forwarded")
    XCTAssertFalse(searchBox.isFocused, "Search box should not be focused for Control combinations")
  }

  // MARK: Option Key Combinations

  func testOptionKeyCombinations_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types Option combinations
    simulateKeystroke("a", modifiers: [.option])  // Option+A
    simulateKeystroke("b", modifiers: [.option])  // Option+B

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Option combinations should not be forwarded")
    XCTAssertFalse(searchBox.isFocused, "Search box should not be focused for Option combinations")
  }

  func testOptionKeyCombinations_SpecialCharacters_Preserved() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types Option combinations for special characters
    simulateKeystroke("g", modifiers: [.option])  // Option+G (copyright symbol)
    simulateKeystroke("2", modifiers: [.option])  // Option+2 (trademark symbol)

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Option combinations should not be forwarded")
    XCTAssertFalse(searchBox.isFocused, "Search box should not be focused for Option combinations")
  }

  // MARK: Shift Key Alone

  func testShiftKeyAlone_CharactersAreForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types Shift+letter combinations
    simulateKeystroke("A", modifiers: [.shift])  // Shift+A
    simulateKeystroke("B", modifiers: [.shift])  // Shift+B

    // Then: Characters should appear in search box
    XCTAssertEqual(searchBox.text, "AB", "Shift+letter combinations should be forwarded")
    XCTAssertTrue(searchBox.isFocused, "Search box should be focused for Shift+letter combinations")
  }

  func testShiftKeyAlone_NumbersAndSymbols_AreForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types Shift+number/symbol combinations
    simulateKeystroke("!", modifiers: [.shift])  // Shift+1
    simulateKeystroke("@", modifiers: [.shift])  // Shift+2
    simulateKeystroke("#", modifiers: [.shift])  // Shift+3

    // Then: Symbols should appear in search box
    XCTAssertEqual(searchBox.text, "!@#", "Shift+symbol combinations should be forwarded")
    XCTAssertTrue(searchBox.isFocused, "Search box should be focused for Shift+symbol combinations")
  }

  // MARK: Multiple Modifier Combinations

  func testMultipleModifierCombinations_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types multiple modifier combinations
    simulateKeystroke("s", modifiers: [.command, .option])  // Command+Option+S
    simulateKeystroke("r", modifiers: [.command, .shift])  // Command+Shift+R
    simulateKeystroke("t", modifiers: [.control, .option])  // Control+Option+T

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Multiple modifier combinations should not be forwarded")
    XCTAssertFalse(
      searchBox.isFocused, "Search box should not be focused for multiple modifier combinations")
  }

  func testAllModifiersTogether_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types with all modifiers
    simulateKeystroke("x", modifiers: [.command, .control, .option, .shift])  // All modifiers

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "All modifier combinations should not be forwarded")
    XCTAssertFalse(
      searchBox.isFocused, "Search box should not be focused for all modifier combinations")
  }

  // MARK: Function Keys

  func testFunctionKeys_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User presses function keys
    simulateFunctionKey(.F1)
    simulateFunctionKey(.F2)
    simulateFunctionKey(.F10)
    simulateFunctionKey(.F12)

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Function keys should not be forwarded")
    XCTAssertFalse(searchBox.isFocused, "Search box should not be focused for function keys")
  }

  func testFunctionKeysWithModifiers_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User presses function keys with modifiers
    simulateFunctionKey(.F1, modifiers: [.command])
    simulateFunctionKey(.F2, modifiers: [.control])
    simulateFunctionKey(.F3, modifiers: [.option])

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Function keys with modifiers should not be forwarded")
    XCTAssertFalse(
      searchBox.isFocused, "Search box should not be focused for function keys with modifiers")
  }

  // MARK: Special Keys

  func testSpecialKeys_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User presses special keys
    simulateSpecialKey(.escape)
    simulateSpecialKey(.tab)
    simulateSpecialKey(.return)
    simulateSpecialKey(.delete)
    simulateSpecialKey(.upArrow)
    simulateSpecialKey(.downArrow)
    simulateSpecialKey(.leftArrow)
    simulateSpecialKey(.rightArrow)

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Special keys should not be forwarded")
    XCTAssertFalse(searchBox.isFocused, "Search box should not be focused for special keys")
  }

  func testSpecialKeysWithModifiers_AreNotForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User presses special keys with modifiers
    simulateSpecialKey(.tab, modifiers: [.control])  // Control+Tab
    simulateSpecialKey(.return, modifiers: [.command])  // Command+Return
    simulateSpecialKey(.escape, modifiers: [.option])  // Option+Escape

    // Then: No characters should appear in search box
    XCTAssertEqual(searchBox.text, "", "Special keys with modifiers should not be forwarded")
    XCTAssertFalse(
      searchBox.isFocused, "Search box should not be focused for special keys with modifiers")
  }

  // MARK: Mixed Scenarios

  func testMixedTyping_ModifierAndNormalKeys_OnlyNormalKeysForwarded() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types mix of modifier and normal keys
    simulateKeystroke("h", modifiers: [])  // Normal key
    simulateKeystroke("e", modifiers: [])  // Normal key
    simulateKeystroke("l", modifiers: [.command])  // Command+L (should be ignored)
    simulateKeystroke("l", modifiers: [])  // Normal key
    simulateKeystroke("o", modifiers: [])  // Normal key
    simulateKeystroke("s", modifiers: [.control])  // Control+S (should be ignored)

    // Then: Only normal keys should appear in search box
    XCTAssertEqual(searchBox.text, "hello", "Only normal keys should be forwarded")
    XCTAssertTrue(searchBox.isFocused, "Search box should be focused for normal keys")
  }

  func testMixedTyping_ModifierKeysDoNotTriggerFocus() {
    // Given: AltSwitch window is visible and search box is unfocused
    mainWindow.show()
    XCTAssertFalse(searchBox.isFocused)

    // When: User types only modifier key combinations
    simulateKeystroke("c", modifiers: [.command])
    simulateKeystroke("v", modifiers: [.command])
    simulateKeystroke("x", modifiers: [.control])

    // Then: Search box should remain unfocused
    XCTAssertFalse(searchBox.isFocused, "Search box should remain unfocused for modifier keys only")
    XCTAssertEqual(searchBox.text, "", "No text should appear for modifier keys only")
  }

  func testMixedTyping_NormalKeyAfterModifierKeys_TriggersFocus() {
    // Given: AltSwitch window is visible and search box is unfocused
    mainWindow.show()
    XCTAssertFalse(searchBox.isFocused)

    // When: User types modifier keys then normal key
    simulateKeystroke("c", modifiers: [.command])  // Should not trigger focus
    simulateKeystroke("a", modifiers: [])  // Should trigger focus

    // Then: Search box should be focused and contain normal key
    XCTAssertTrue(searchBox.isFocused, "Search box should be focused after normal key")
    XCTAssertEqual(searchBox.text, "a", "Only normal key should appear")
  }

  // MARK: System Integration

  func testSystemShortcuts_ContinueToWork() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types system shortcuts
    let systemEvents = [
      createSystemEvent(keyCode: 0x08, modifiers: [.command]),  // Command+C (copy)
      createSystemEvent(keyCode: 0x09, modifiers: [.command]),  // Command+V (paste)
      createSystemEvent(keyCode: 0x07, modifiers: [.command]),  // Command+X (cut)
      createSystemEvent(keyCode: 0x00, modifiers: [.command, .shift]),  // Command+Shift+A
    ]

    for event in systemEvents {
      let handled = keystrokeHandler.handleEvent(event)
      if !handled {
        interceptedSystemEvents.append(event)
      }
    }

    // Then: System events should not be handled by keystroke handler
    XCTAssertEqual(
      interceptedSystemEvents.count, 4,
      "System shortcuts should not be handled by keystroke handler")
    XCTAssertEqual(searchBox.text, "", "System shortcuts should not affect search box")
    XCTAssertFalse(searchBox.isFocused, "System shortcuts should not focus search box")
  }

  func testApplicationShortcuts_ContinueToWork() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types application-specific shortcuts
    let appEvents = [
      createSystemEvent(keyCode: 0x0C, modifiers: [.command]),  // Command+Q (quit)
      createSystemEvent(keyCode: 0x0F, modifiers: [.command]),  // Command+O (open)
      createSystemEvent(keyCode: 0x10, modifiers: [.command]),  // Command+P (print)
      createSystemEvent(keyCode: 0x13, modifiers: [.command]),  // Command+S (save)
    ]

    for event in appEvents {
      let handled = keystrokeHandler.handleEvent(event)
      if !handled {
        interceptedSystemEvents.append(event)
      }
    }

    // Then: Application shortcuts should not be handled by keystroke handler
    XCTAssertEqual(
      interceptedSystemEvents.count, 4,
      "Application shortcuts should not be handled by keystroke handler")
    XCTAssertEqual(searchBox.text, "", "Application shortcuts should not affect search box")
    XCTAssertFalse(searchBox.isFocused, "Application shortcuts should not focus search box")
  }

  // MARK: - Helper Methods

  private func setupTestComponents() {
    keystrokeHandler = createKeystrokeHandler()
    focusManager = createFocusManager()
    searchBox = createSearchBox()
    mainWindow = createMainWindow()

    // Connect components for integration testing
    keystrokeHandler.onKeystroke = { [weak self] keystroke in
      self?.focusManager?.handleKeystroke(keystroke)
    }

    focusManager.onFocusStateChange = { [weak self] _, isFocused in
      if isFocused {
        self?.searchBox?.focus()
      } else {
        self?.searchBox?.unfocus()
      }
    }

    keystrokeHandler.startMonitoring()
  }

  private func teardownTestComponents() {
    keystrokeHandler?.stopMonitoring()
    keystrokeHandler = nil
    focusManager = nil
    searchBox = nil
    mainWindow = nil
  }

  private func simulateKeystroke(_ character: String, modifiers: NSEvent.ModifierFlags = []) {
    let keystroke = KeystrokeEvent(
      character: character,
      keyCode: 0,
      modifierFlags: modifiers,
      timestamp: Date(),
      isPrintable: modifiers.isEmpty && !character.isEmpty
    )

    keystrokeHandler.onKeystroke?(keystroke)
  }

  private func simulateFunctionKey(
    _ functionKey: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags = []
  ) {
    let event = createSystemEvent(keyCode: functionKey.rawValue, modifiers: modifiers)
    keystrokeHandler.handleEvent(event)
  }

  private func simulateSpecialKey(
    _ specialKey: NSEvent.SpecialKey, modifiers: NSEvent.ModifierFlags = []
  ) {
    let event = createSystemEvent(keyCode: specialKey.rawValue, modifiers: modifiers)
    keystrokeHandler.handleEvent(event)
  }

  private func createSystemEvent(keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) -> NSEvent
  {
    return NSEvent.keyEvent(
      with: .keyDown,
      location: NSPoint.zero,
      modifierFlags: modifiers,
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      characters: "",
      charactersIgnoringModifiers: "",
      isARepeat: false,
      keyCode: keyCode
    )!
  }
}

// MARK: - Mock Extensions

extension ModifierKeyTests {
  // Default mock implementations for testing
  func createDefaultKeystrokeHandler() -> any KeystrokeHandlerProtocol {
    return MockKeystrokeHandler()
  }

  func createDefaultFocusManager() -> any FocusManagerProtocol {
    return MockFocusManager()
  }

  func createDefaultSearchBox() -> any SearchBoxIntegrationProtocol {
    return MockSearchBox()
  }

  func createDefaultMainWindow() -> MainWindow {
    return MockMainWindow()
  }
}

// MARK: - Mock Classes

private class MockKeystrokeHandler: KeystrokeHandlerProtocol {
  var onKeystroke: ((KeystrokeEvent) -> Void)?
  var isActive: Bool = false

  func startMonitoring() {
    isActive = true
  }

  func stopMonitoring() {
    isActive = false
  }

  func handleEvent(_ event: NSEvent) -> Bool {
    let isPrintable = isPrintableCharacter(event)
    let keystroke = KeystrokeEvent(
      character: event.characters ?? "",
      keyCode: event.keyCode,
      modifierFlags: event.modifierFlags,
      timestamp: Date(),
      isPrintable: isPrintable
    )

    if isPrintable {
      onKeystroke?(keystroke)
      return true
    }

    return false
  }

  private func isPrintableCharacter(_ event: NSEvent) -> Bool {
    guard let characters = event.characters else { return false }
    let hasModifiers = !event.modifierFlags.intersection([.command, .control, .option]).isEmpty
    return !characters.isEmpty && !hasModifiers
  }
}

private class MockFocusManager: FocusManagerProtocol {
  var isWindowVisible: Bool = false
  var isSearchFieldFocused: Bool = false
  var isTransitioningFocus: Bool = false

  var onFocusStateChange: ((Bool, Bool) -> Void)?
  var onFocusTransition: ((Bool) -> Void)?

  func showWindow() {
    isWindowVisible = true
    onFocusStateChange?(isWindowVisible, isSearchFieldFocused)
  }

  func hideWindow() {
    isWindowVisible = false
    isSearchFieldFocused = false
    onFocusStateChange?(isWindowVisible, isSearchFieldFocused)
  }

  func focusSearchField() {
    if isWindowVisible {
      isSearchFieldFocused = true
      onFocusStateChange?(isWindowVisible, isSearchFieldFocused)
    }
  }

  func unfocusSearchField() {
    isSearchFieldFocused = false
    onFocusStateChange?(isWindowVisible, isSearchFieldFocused)
  }

  func handleKeystroke(_ keystroke: KeystrokeEvent) {
    if isWindowVisible && !isSearchFieldFocused {
      focusSearchField()
    }
  }
}

private class MockSearchBox: SearchBoxIntegrationProtocol {
  var text: String = ""
  var isFocused: Bool = false
  var isEmpty: Bool { return text.isEmpty }
  var selectedRange: NSRange = NSRange(location: 0, length: 0)

  var onTextChange: ((String) -> Void)?
  var onFocusChange: ((Bool) -> Void)?

  func setText(_ newText: String) {
    text = newText
    onTextChange?(text)
  }

  func focus() {
    isFocused = true
    onFocusChange?(isFocused)
  }

  func unfocus() {
    isFocused = false
    onFocusChange?(isFocused)
  }

  func injectCharacter(_ character: String) {
    text += character
    onTextChange?(text)
  }

  func clearText() {
    text = ""
    onTextChange?(text)
  }

  func deleteLastCharacter() {
    if !text.isEmpty {
      text.removeLast()
      onTextChange?(text)
    }
  }

  func selectAll() {
    selectedRange = NSRange(location: 0, length: text.utf16.count)
  }

  func selectRange(location: Int, length: Int) {
    let maxLocation = text.utf16.count
    let clampedLocation = min(max(0, location), maxLocation)
    let maxLength = maxLocation - clampedLocation
    let clampedLength = min(max(0, length), maxLength)

    selectedRange = NSRange(location: clampedLocation, length: clampedLength)
  }
}

private class MockMainWindow: MainWindow {
  var isVisible: Bool = false

  func show() {
    isVisible = true
  }

  func hide() {
    isVisible = false
  }
}
