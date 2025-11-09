import XCTest

@testable import AltSwitch

/// Integration tests for basic character forwarding scenario
///
/// Requirements from quickstart.md:
/// - When AltSwitch window is visible, typing should automatically go to search box
/// - No manual focus management required
/// - Characters should appear immediately in search field
/// - Should work with any printable character
final class GlobalKeystrokeTests: XCTestCase {

  // MARK: - Test Properties

  private var keystrokeHandler: any KeystrokeHandlerProtocol!
  private var focusManager: any FocusManagerProtocol!
  private var searchBox: any SearchBoxIntegrationProtocol!
  private var mainWindow: MainWindow!
  private var receivedKeystrokes: [KeystrokeEvent] = []

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()
    setupTestComponents()
    receivedKeystrokes = []
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

  // MARK: Basic Character Forwarding

  func testBasicCharacterForwarding_WindowVisible_CharacterAppearsInSearchBox() {
    // Given: AltSwitch window is visible and search box is empty
    mainWindow.show()
    XCTAssertTrue(mainWindow.isVisible)
    XCTAssertEqual(searchBox.text, "")

    // When: User types a printable character
    simulateKeystroke("a")

    // Then: Character should appear in search box
    XCTAssertEqual(searchBox.text, "a", "Character 'a' should appear in search box")
    XCTAssertTrue(searchBox.isFocused, "Search box should be automatically focused")
  }

  func testBasicCharacterForwarding_MultipleCharacters_AccumulateInSearchBox() {
    // Given: AltSwitch window is visible
    mainWindow.show()
    XCTAssertTrue(mainWindow.isVisible)

    // When: User types multiple characters
    simulateKeystroke("h")
    simulateKeystroke("e")
    simulateKeystroke("l")
    simulateKeystroke("l")
    simulateKeystroke("o")

    // Then: All characters should accumulate in search box
    XCTAssertEqual(searchBox.text, "hello", "Multiple characters should accumulate in search box")
    XCTAssertTrue(searchBox.isFocused, "Search box should remain focused")
  }

  func testBasicCharacterForwarding_WindowHidden_CharacterIgnored() {
    // Given: AltSwitch window is hidden
    XCTAssertFalse(mainWindow.isVisible)
    XCTAssertEqual(searchBox.text, "")

    // When: User types a character
    simulateKeystroke("a")

    // Then: Character should not appear in search box
    XCTAssertEqual(searchBox.text, "", "Character should be ignored when window is hidden")
    XCTAssertFalse(searchBox.isFocused, "Search box should remain unfocused")
  }

  func testBasicCharacterForwarding_WindowShownAfterTyping_StartsNewText() {
    // Given: AltSwitch window is hidden and user types
    XCTAssertFalse(mainWindow.isVisible)
    simulateKeystroke("x")  // Should be ignored

    // When: Window is shown and user types
    mainWindow.show()
    simulateKeystroke("a")

    // Then: Only characters typed after window shown should appear
    XCTAssertEqual(searchBox.text, "a", "Only characters typed after window shown should appear")
    XCTAssertTrue(searchBox.isFocused, "Search box should be focused")
  }

  // MARK: Character Types

  func testBasicCharacterForwarding_LowercaseLetters_WorkCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types lowercase letters
    simulateKeystroke("a")
    simulateKeystroke("b")
    simulateKeystroke("c")

    // Then: Letters should appear correctly
    XCTAssertEqual(searchBox.text, "abc", "Lowercase letters should work correctly")
  }

  func testBasicCharacterForwarding_UppercaseLetters_WorkCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types uppercase letters (with shift)
    simulateKeystroke("A")
    simulateKeystroke("B")
    simulateKeystroke("C")

    // Then: Uppercase letters should appear correctly
    XCTAssertEqual(searchBox.text, "ABC", "Uppercase letters should work correctly")
  }

  func testBasicCharacterForwarding_Numbers_WorkCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types numbers
    simulateKeystroke("1")
    simulateKeystroke("2")
    simulateKeystroke("3")

    // Then: Numbers should appear correctly
    XCTAssertEqual(searchBox.text, "123", "Numbers should work correctly")
  }

  func testBasicCharacterForwarding_SpecialCharacters_WorkCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types special characters
    simulateKeystroke("!")
    simulateKeystroke("@")
    simulateKeystroke("#")

    // Then: Special characters should appear correctly
    XCTAssertEqual(searchBox.text, "!@#", "Special characters should work correctly")
  }

  func testBasicCharacterForwarding_SpaceCharacter_WorkCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types space
    simulateKeystroke(" ")

    // Then: Space should appear correctly
    XCTAssertEqual(searchBox.text, " ", "Space character should work correctly")
  }

  func testBasicCharacterForwarding_MixedCharacterTypes_WorkCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types mixed characters
    simulateKeystroke("H")
    simulateKeystroke("e")
    simulateKeystroke("l")
    simulateKeystroke("l")
    simulateKeystroke("o")
    simulateKeystroke(" ")
    simulateKeystroke("1")
    simulateKeystroke("2")
    simulateKeystroke("3")
    simulateKeystroke("!")

    // Then: All characters should appear correctly
    XCTAssertEqual(searchBox.text, "Hello 123!", "Mixed character types should work correctly")
  }

  // MARK: Timing and Performance

  func testBasicCharacterForwarding_RapidTyping_HandlesCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types rapidly (simulating fast typing)
    let characters = Array("The quick brown fox jumps over the lazy dog")
    for character in characters {
      simulateKeystroke(String(character))
    }

    // Then: All characters should appear in correct order
    XCTAssertEqual(
      searchBox.text, "The quick brown fox jumps over the lazy dog",
      "Rapid typing should be handled correctly")
  }

  func testBasicCharacterForwarding_CharacterTiming_ImmediateResponse() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    let expectation = XCTestExpectation(description: "Character should appear immediately")

    // When: User types a character
    searchBox.onTextChange = { text in
      if text == "a" {
        expectation.fulfill()
      }
    }

    simulateKeystroke("a")

    // Then: Character should appear immediately (within reasonable time)
    wait(for: [expectation], timeout: 0.1)  // 100ms should be more than enough
    XCTAssertEqual(searchBox.text, "a", "Character should appear immediately")
  }

  // MARK: State Management

  func testBasicCharacterForwarding_FocusState_AutoFocusOnFirstCharacter() {
    // Given: AltSwitch window is visible and search box is unfocused
    mainWindow.show()
    XCTAssertFalse(searchBox.isFocused)

    // When: User types first character
    simulateKeystroke("a")

    // Then: Search box should be automatically focused
    XCTAssertTrue(searchBox.isFocused, "Search box should be auto-focused on first character")
    XCTAssertEqual(searchBox.text, "a", "Character should appear in search box")
  }

  func testBasicCharacterForwarding_FocusState_RemainsFocusedAfterTyping() {
    // Given: AltSwitch window is visible and user types
    mainWindow.show()
    simulateKeystroke("a")
    XCTAssertTrue(searchBox.isFocused)

    // When: User types more characters
    simulateKeystroke("b")
    simulateKeystroke("c")

    // Then: Search box should remain focused
    XCTAssertTrue(searchBox.isFocused, "Search box should remain focused during typing")
    XCTAssertEqual(searchBox.text, "abc", "Characters should accumulate correctly")
  }

  func testBasicCharacterForwarding_WindowHide_ResetsFocusState() {
    // Given: AltSwitch window is visible and user has typed
    mainWindow.show()
    simulateKeystroke("a")
    XCTAssertTrue(searchBox.isFocused)
    XCTAssertEqual(searchBox.text, "a")

    // When: Window is hidden
    mainWindow.hide()

    // Then: Focus state should be reset
    XCTAssertFalse(searchBox.isFocused, "Search box should be unfocused when window hidden")
    XCTAssertEqual(searchBox.text, "a", "Text should be preserved when window hidden")
  }

  func testBasicCharacterForwarding_WindowShowAgain_ResumesTyping() {
    // Given: AltSwitch window was shown, hidden, and shown again
    mainWindow.show()
    simulateKeystroke("a")
    mainWindow.hide()
    mainWindow.show()

    // When: User types more characters
    simulateKeystroke("b")

    // Then: Typing should resume normally
    XCTAssertTrue(searchBox.isFocused, "Search box should be focused when window shown again")
    XCTAssertEqual(searchBox.text, "ab", "Typing should resume with existing text")
  }

  // MARK: Edge Cases

  func testBasicCharacterForwarding_EmptyCharacter_Ignored() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: Simulating empty character
    simulateKeystroke("")

    // Then: Empty character should be ignored
    XCTAssertEqual(searchBox.text, "", "Empty character should be ignored")
    XCTAssertFalse(searchBox.isFocused, "Search box should not be focused for empty character")
  }

  func testBasicCharacterForwarding_VeryLongText_HandlesCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    // When: User types very long text
    let longText = String(repeating: "a", count: 1000)
    for character in longText {
      simulateKeystroke(String(character))
    }

    // Then: Long text should be handled correctly
    XCTAssertEqual(searchBox.text, longText, "Very long text should be handled correctly")
    XCTAssertTrue(searchBox.isFocused, "Search box should remain focused for long text")
  }

  // MARK: - Helper Methods

  private func setupTestComponents() {
    keystrokeHandler = createKeystrokeHandler()
    focusManager = createFocusManager()
    searchBox = createSearchBox()
    mainWindow = createMainWindow()

    // Connect components for integration testing
    keystrokeHandler.onKeystroke = { [weak self] keystroke in
      self?.receivedKeystrokes.append(keystroke)
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

  private func simulateKeystroke(_ character: String) {
    let keystroke = KeystrokeEvent(
      character: character,
      keyCode: 0,
      modifierFlags: [],
      timestamp: Date(),
      isPrintable: !character.isEmpty
    )

    keystrokeHandler.onKeystroke?(keystroke)
  }
}

// MARK: - Mock Extensions

extension GlobalKeystrokeTests {
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
    let keystroke = KeystrokeEvent(
      character: event.characters ?? "",
      keyCode: event.keyCode,
      modifierFlags: event.modifierFlags,
      timestamp: Date(),
      isPrintable: isPrintableCharacter(event)
    )
    onKeystroke?(keystroke)
    return true
  }

  private func isPrintableCharacter(_ event: NSEvent) -> Bool {
    guard let characters = event.characters else { return false }
    return !characters.isEmpty
      && event.modifierFlags.intersection([.command, .control, .option]).isEmpty
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
