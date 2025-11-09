import XCTest

@testable import AltSwitch

/// Contract tests for SearchBoxIntegrationProtocol
///
/// Requirements from contracts/SearchBoxIntegrationProtocol.swift:
/// - Manages search field focus state and text content
/// - Handles character injection from global keystrokes
/// - Coordinates with focus manager for automatic focus
/// - Provides search state observation for UI updates
/// - Supports both programmatic and user input
/// - Maintains cursor position and selection state
final class SearchBoxIntegrationContractTests: XCTestCase {

  // MARK: - Test Properties

  private var searchBox: any SearchBoxIntegrationProtocol!
  private var focusManager: MockFocusManager!
  private var keystrokeHandler: MockKeystrokeHandler!
  private var textChangeCount = 0

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()
    focusManager = MockFocusManager()
    keystrokeHandler = MockKeystrokeHandler()
    searchBox = createSearchBox()
    textChangeCount = 0
  }

  override func tearDown() {
    searchBox = nil
    focusManager = nil
    keystrokeHandler = nil
    super.tearDown()
  }

  // MARK: - Factory Method

  /// Creates a concrete implementation of SearchBoxIntegrationProtocol
  /// Implementations must override this to return their instance
  func createSearchBox() -> any SearchBoxIntegrationProtocol {
    fatalError("Subclasses must implement createSearchBox()")
  }

  // MARK: - Contract Tests

  // MARK: Initial State

  func testInitialState_HasEmptyTextAndUnfocused() {
    // Given: A newly created search box

    // When: Checking initial state
    let text = searchBox.text
    let isFocused = searchBox.isFocused
    let isEmpty = searchBox.isEmpty

    // Then: Should have empty text and be unfocused
    XCTAssertEqual(text, "", "Search text should be empty initially")
    XCTAssertFalse(isFocused, "Search box should be unfocused initially")
    XCTAssertTrue(isEmpty, "Search box should be empty initially")
  }

  func testInitialState_HasNoActiveTextSelection() {
    // Given: A newly created search box

    // When: Checking selection state
    let selectedRange = searchBox.selectedRange

    // Then: Should have no selection
    XCTAssertEqual(selectedRange.location, 0, "Selection location should be 0 initially")
    XCTAssertEqual(selectedRange.length, 0, "Selection length should be 0 initially")
  }

  // MARK: Text Management

  func testSetText_UpdatesTextContent() {
    // Given: A search box with empty text
    XCTAssertEqual(searchBox.text, "")

    // When: Setting text
    let testText = "test query"
    searchBox.setText(testText)

    // Then: Text should be updated
    XCTAssertEqual(searchBox.text, testText, "Text should be updated after setText()")
    XCTAssertFalse(searchBox.isEmpty, "Search box should not be empty after setting text")
  }

  func testSetText_EmptyString_MarksAsEmpty() {
    // Given: A search box with text
    searchBox.setText("test")
    XCTAssertFalse(searchBox.isEmpty)

    // When: Setting empty text
    searchBox.setText("")

    // Then: Should be marked as empty
    XCTAssertEqual(searchBox.text, "", "Text should be empty after setting empty string")
    XCTAssertTrue(searchBox.isEmpty, "Search box should be marked as empty")
  }

  func testSetText_TriggersTextChangeCallback() {
    // Given: A search box with text change callback
    let expectation = XCTestExpectation(description: "Text change should be triggered")

    searchBox.onTextChange = { newText in
      XCTAssertEqual(newText, "test query")
      expectation.fulfill()
    }

    // When: Setting text
    searchBox.setText("test query")

    // Then: Text change callback should be triggered
    wait(for: [expectation], timeout: 1.0)
  }

  // MARK: Focus Management

  func testFocus_UpdatesFocusState() {
    // Given: A search box that is unfocused
    XCTAssertFalse(searchBox.isFocused)

    // When: Focusing the search box
    searchBox.focus()

    // Then: Focus state should be updated
    XCTAssertTrue(searchBox.isFocused, "Search box should be focused after focus()")
  }

  func testUnfocus_UpdatesFocusState() {
    // Given: A search box that is focused
    searchBox.focus()
    XCTAssertTrue(searchBox.isFocused)

    // When: Unfocusing the search box
    searchBox.unfocus()

    // Then: Focus state should be updated
    XCTAssertFalse(searchBox.isFocused, "Search box should be unfocused after unfocus()")
  }

  func testFocus_TriggersFocusChangeCallback() {
    // Given: A search box with focus change callback
    let expectation = XCTestExpectation(description: "Focus change should be triggered")
    expectation.expectedFulfillmentCount = 2  // focus + unfocus

    searchBox.onFocusChange = { _ in
      expectation.fulfillmentCount += 1
    }

    // When: Changing focus state
    searchBox.focus()
    searchBox.unfocus()

    // Then: Focus change callback should be triggered
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(
      expectation.fulfillmentCount, 2,
      "Focus change callback should be triggered for each focus change")
  }

  // MARK: Character Injection

  func testInjectCharacter_AppendsToText() {
    // Given: A search box with existing text
    searchBox.setText("test")
    XCTAssertEqual(searchBox.text, "test")

    // When: Injecting a character
    searchBox.injectCharacter("a")

    // Then: Character should be appended
    XCTAssertEqual(searchBox.text, "testa", "Character should be appended to existing text")
  }

  func testInjectCharacter_WhenEmpty_SetsText() {
    // Given: A search box with empty text
    XCTAssertEqual(searchBox.text, "")

    // When: Injecting a character
    searchBox.injectCharacter("a")

    // Then: Text should be set to the character
    XCTAssertEqual(searchBox.text, "a", "Character should set text when empty")
  }

  func testInjectCharacter_MultipleCharacters_AppendsInOrder() {
    // Given: A search box with empty text

    // When: Injecting multiple characters
    searchBox.injectCharacter("h")
    searchBox.injectCharacter("e")
    searchBox.injectCharacter("l")
    searchBox.injectCharacter("l")
    searchBox.injectCharacter("o")

    // Then: Characters should be appended in order
    XCTAssertEqual(searchBox.text, "hello", "Multiple characters should be appended in order")
  }

  func testInjectCharacter_TriggersTextChangeCallback() {
    // Given: A search box with text change callback
    let expectation = XCTestExpectation(description: "Text change should be triggered")
    expectation.expectedFulfillmentCount = 3  // h + e + l

    searchBox.onTextChange = { _ in
      expectation.fulfillmentCount += 1
    }

    // When: Injecting multiple characters
    searchBox.injectCharacter("h")
    searchBox.injectCharacter("e")
    searchBox.injectCharacter("l")

    // Then: Text change callback should be triggered for each character
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(
      expectation.fulfillmentCount, 3,
      "Text change callback should be triggered for each injected character")
  }

  // MARK: Text Manipulation

  func testClearText_EmptiesTextContent() {
    // Given: A search box with text
    searchBox.setText("test query")
    XCTAssertFalse(searchBox.isEmpty)

    // When: Clearing text
    searchBox.clearText()

    // Then: Text should be empty
    XCTAssertEqual(searchBox.text, "", "Text should be empty after clearText()")
    XCTAssertTrue(searchBox.isEmpty, "Search box should be marked as empty")
  }

  func testClearText_TriggersTextChangeCallback() {
    // Given: A search box with text and text change callback
    searchBox.setText("test query")
    let expectation = XCTestExpectation(description: "Text change should be triggered")

    searchBox.onTextChange = { newText in
      XCTAssertEqual(newText, "")
      expectation.fulfill()
    }

    // When: Clearing text
    searchBox.clearText()

    // Then: Text change callback should be triggered
    wait(for: [expectation], timeout: 1.0)
  }

  func testDeleteLastCharacter_RemovesLastCharacter() {
    // Given: A search box with text
    searchBox.setText("hello")
    XCTAssertEqual(searchBox.text, "hello")

    // When: Deleting last character
    searchBox.deleteLastCharacter()

    // Then: Last character should be removed
    XCTAssertEqual(searchBox.text, "hell", "Last character should be removed")
  }

  func testDeleteLastCharacter_WhenSingleCharacter_EmptiesText() {
    // Given: A search box with single character
    searchBox.setText("a")
    XCTAssertEqual(searchBox.text, "a")

    // When: Deleting last character
    searchBox.deleteLastCharacter()

    // Then: Text should be empty
    XCTAssertEqual(searchBox.text, "", "Text should be empty after deleting last character")
    XCTAssertTrue(searchBox.isEmpty, "Search box should be marked as empty")
  }

  func testDeleteLastCharacter_WhenEmpty_DoesNothing() {
    // Given: A search box with empty text
    XCTAssertEqual(searchBox.text, "")
    XCTAssertTrue(searchBox.isEmpty)

    // When: Attempting to delete last character
    searchBox.deleteLastCharacter()

    // Then: Text should remain empty
    XCTAssertEqual(
      searchBox.text, "", "Text should remain empty when attempting to delete from empty")
    XCTAssertTrue(searchBox.isEmpty, "Search box should remain marked as empty")
  }

  // MARK: Selection Management

  func testSelectAll_SelectsEntireText() {
    // Given: A search box with text
    searchBox.setText("hello world")

    // When: Selecting all text
    searchBox.selectAll()

    // Then: Entire text should be selected
    let selectedRange = searchBox.selectedRange
    XCTAssertEqual(selectedRange.location, 0, "Selection should start at beginning")
    XCTAssertEqual(selectedRange.length, 11, "Selection should cover entire text")
  }

  func testSelectRange_SelectsSpecifiedRange() {
    // Given: A search box with text
    searchBox.setText("hello world")

    // When: Selecting a specific range
    searchBox.selectRange(location: 2, length: 3)

    // Then: Specified range should be selected
    let selectedRange = searchBox.selectedRange
    XCTAssertEqual(selectedRange.location, 2, "Selection should start at specified location")
    XCTAssertEqual(selectedRange.length, 3, "Selection should have specified length")
  }

  func testSelectRange_InvalidLocation_ClampsToValidRange() {
    // Given: A search box with text
    searchBox.setText("hello")

    // When: Selecting range with invalid location
    searchBox.selectRange(location: 10, length: 5)

    // Then: Location should be clamped to valid range
    let selectedRange = searchBox.selectedRange
    XCTAssertEqual(selectedRange.location, 5, "Location should be clamped to text length")
    XCTAssertEqual(selectedRange.length, 0, "Length should be adjusted for clamped location")
  }

  // MARK: Integration with Focus Manager

  func testFocusManagerFocusChange_UpdatesSearchBoxFocus() {
    // Given: A search box integrated with focus manager
    XCTAssertFalse(searchBox.isFocused)

    // When: Focus manager indicates focus change
    focusManager.simulateFocusChange(isFocused: true)

    // Then: Search box focus should be updated
    XCTAssertTrue(
      searchBox.isFocused, "Search box should be focused when focus manager indicates focus")
  }

  func testFocusManagerKeystroke_InjectsCharacter() {
    // Given: A search box integrated with focus manager
    XCTAssertEqual(searchBox.text, "")

    // When: Focus manager indicates keystroke
    focusManager.simulateKeystroke("a")

    // Then: Character should be injected
    XCTAssertEqual(
      searchBox.text, "a", "Character should be injected when focus manager indicates keystroke")
  }

  // MARK: Edge Cases

  func testRapidCharacterInjection_HandlesGracefully() {
    // Given: A search box

    // When: Rapidly injecting characters
    let characters = Array("hello world")
    for character in characters {
      searchBox.injectCharacter(String(character))
    }

    // Then: Text should contain all characters in order
    XCTAssertEqual(
      searchBox.text, "hello world", "Rapid character injection should be handled gracefully")
  }

  func testSpecialCharacterInjection_HandlesCorrectly() {
    // Given: A search box

    // When: Injecting special characters
    searchBox.injectCharacter("é")
    searchBox.injectCharacter("ñ")
    searchBox.injectCharacter("ü")

    // Then: Special characters should be handled correctly
    XCTAssertEqual(searchBox.text, "éñü", "Special characters should be handled correctly")
  }

  func testEmptyCharacterInjection_DoesNothing() {
    // Given: A search box with existing text
    searchBox.setText("test")
    XCTAssertEqual(searchBox.text, "test")

    // When: Injecting empty character
    searchBox.injectCharacter("")

    // Then: Text should remain unchanged
    XCTAssertEqual(searchBox.text, "test", "Empty character injection should not change text")
  }
}

// MARK: - Mock Objects

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

  // Helper methods for testing
  func simulateFocusChange(isFocused: Bool) {
    isSearchFieldFocused = isFocused
    onFocusStateChange?(isWindowVisible, isSearchFieldFocused)
  }

  func simulateKeystroke(_ character: String) {
    let keystroke = KeystrokeEvent(
      character: character,
      keyCode: 0,
      modifierFlags: [],
      timestamp: Date(),
      isPrintable: true
    )
    handleKeystroke(keystroke)
  }
}

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
