import XCTest

@testable import AltSwitch

/// Contract tests for FocusManagerProtocol
///
/// Requirements from contracts/FocusManagerProtocol.swift:
/// - Manages focus state between window visibility and search field
/// - Coordinates with keystroke handler for automatic focus
/// - Provides focus state observation for UI updates
/// - Handles focus transitions during window show/hide
/// - Supports manual focus override capabilities
final class FocusManagerContractTests: XCTestCase {

  // MARK: - Test Properties

  private var focusManager: any FocusManagerProtocol!
  private var keystrokeHandler: MockKeystrokeHandler!
  private var expectationFulfillmentCount = 0

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()
    keystrokeHandler = MockKeystrokeHandler()
    focusManager = createFocusManager()
    expectationFulfillmentCount = 0
  }

  override func tearDown() {
    focusManager = nil
    keystrokeHandler = nil
    super.tearDown()
  }

  // MARK: - Factory Method

  /// Creates a concrete implementation of FocusManagerProtocol
  /// Implementations must override this to return their instance
  func createFocusManager() -> any FocusManagerProtocol {
    fatalError("Subclasses must implement createFocusManager()")
  }

  // MARK: - Contract Tests

  // MARK: Initial State

  func testInitialState_HasWindowHiddenAndSearchFieldUnfocused() {
    // Given: A newly created focus manager

    // When: Checking initial state
    let isWindowVisible = focusManager.isWindowVisible
    let isSearchFieldFocused = focusManager.isSearchFieldFocused

    // Then: Window should be hidden and search field unfocused
    XCTAssertFalse(isWindowVisible, "Window should be hidden initially")
    XCTAssertFalse(isSearchFieldFocused, "Search field should be unfocused initially")
  }

  func testInitialState_HasNoActiveFocusTransition() {
    // Given: A newly created focus manager

    // When: Checking transition state
    let isTransitioning = focusManager.isTransitioningFocus

    // Then: No active transition should be in progress
    XCTAssertFalse(isTransitioning, "No focus transition should be in progress initially")
  }

  // MARK: Window Visibility Management

  func testShowWindow_UpdatesVisibilityState() {
    // Given: A focus manager with hidden window
    XCTAssertFalse(focusManager.isWindowVisible)

    // When: Showing the window
    focusManager.showWindow()

    // Then: Window visibility should be updated
    XCTAssertTrue(focusManager.isWindowVisible, "Window should be visible after showWindow()")
  }

  func testHideWindow_UpdatesVisibilityState() {
    // Given: A focus manager with visible window
    focusManager.showWindow()
    XCTAssertTrue(focusManager.isWindowVisible)

    // When: Hiding the window
    focusManager.hideWindow()

    // Then: Window visibility should be updated
    XCTAssertFalse(focusManager.isWindowVisible, "Window should be hidden after hideWindow()")
  }

  func testShowWindow_TriggersFocusTransition() {
    // Given: A focus manager with hidden window

    // When: Showing the window
    let expectation = XCTestExpectation(description: "Focus transition should start")
    focusManager.onFocusTransition = { isTransitioning in
      if isTransitioning {
        expectation.fulfillmentCount += 1
      }
    }

    focusManager.showWindow()

    // Then: Focus transition should be triggered
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(
      expectation.fulfillmentCount, 1, "Focus transition should be triggered when showing window")
  }

  // MARK: Search Field Focus Management

  func testFocusSearchField_UpdatesFocusState() {
    // Given: A focus manager with visible window
    focusManager.showWindow()

    // When: Focusing the search field
    focusManager.focusSearchField()

    // Then: Search field should be focused
    XCTAssertTrue(
      focusManager.isSearchFieldFocused, "Search field should be focused after focusSearchField()")
  }

  func testUnfocusSearchField_UpdatesFocusState() {
    // Given: A focus manager with focused search field
    focusManager.showWindow()
    focusManager.focusSearchField()
    XCTAssertTrue(focusManager.isSearchFieldFocused)

    // When: Unfocusing the search field
    focusManager.unfocusSearchField()

    // Then: Search field should be unfocused
    XCTAssertFalse(
      focusManager.isSearchFieldFocused,
      "Search field should be unfocused after unfocusSearchField()")
  }

  func testFocusSearchField_WhenWindowHidden_DoesNotFocus() {
    // Given: A focus manager with hidden window
    XCTAssertFalse(focusManager.isWindowVisible)

    // When: Attempting to focus search field
    focusManager.focusSearchField()

    // Then: Search field should remain unfocused
    XCTAssertFalse(
      focusManager.isSearchFieldFocused, "Search field should not focus when window is hidden")
  }

  // MARK: Keystroke Integration

  func testKeystrokeReceived_WhenWindowVisible_AutoFocusesSearchField() {
    // Given: A visible window with unfocused search field
    focusManager.showWindow()
    XCTAssertFalse(focusManager.isSearchFieldFocused)

    // When: A keystroke is received
    let keystroke = createTestKeystroke()
    focusManager.handleKeystroke(keystroke)

    // Then: Search field should be automatically focused
    XCTAssertTrue(
      focusManager.isSearchFieldFocused,
      "Search field should be auto-focused when keystroke received")
  }

  func testKeystrokeReceived_WhenWindowHidden_DoesNotFocus() {
    // Given: A hidden window
    XCTAssertFalse(focusManager.isWindowVisible)

    // When: A keystroke is received
    let keystroke = createTestKeystroke()
    focusManager.handleKeystroke(keystroke)

    // Then: Search field should remain unfocused
    XCTAssertFalse(
      focusManager.isSearchFieldFocused, "Search field should not focus when window is hidden")
  }

  func testKeystrokeReceived_TriggersFocusTransition() {
    // Given: A visible window with unfocused search field
    focusManager.showWindow()
    XCTAssertFalse(focusManager.isSearchFieldFocused)

    // When: A keystroke is received
    let expectation = XCTestExpectation(description: "Focus transition should start")
    focusManager.onFocusTransition = { isTransitioning in
      if isTransitioning {
        expectation.fulfillmentCount += 1
      }
    }

    let keystroke = createTestKeystroke()
    focusManager.handleKeystroke(keystroke)

    // Then: Focus transition should be triggered
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(
      expectation.fulfillmentCount, 1,
      "Focus transition should be triggered when keystroke received")
  }

  // MARK: State Observation

  func testFocusStateChanges_TriggersStateChangeCallback() {
    // Given: A focus manager with state change callback
    let expectation = XCTestExpectation(description: "State change should be triggered")
    expectation.expectedFulfillmentCount = 2  // show + focus

    focusManager.onFocusStateChange = { _, _ in
      expectation.fulfillmentCount += 1
    }

    // When: Changing focus state
    focusManager.showWindow()
    focusManager.focusSearchField()

    // Then: State change callback should be triggered
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(
      expectation.fulfillmentCount, 2,
      "State change callback should be triggered for each state change")
  }

  func testFocusTransition_TriggersTransitionCallback() {
    // Given: A focus manager with transition callback
    let expectation = XCTestExpectation(description: "Transition should be triggered")
    expectation.expectedFulfillmentCount = 2  // start + end

    focusManager.onFocusTransition = { _ in
      expectation.fulfillmentCount += 1
    }

    // When: Triggering focus transition
    focusManager.showWindow()
    focusManager.focusSearchField()

    // Then: Transition callback should be triggered
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(
      expectation.fulfillmentCount, 2,
      "Transition callback should be triggered for transition start and end")
  }

  // MARK: Manual Override

  func testManualFocusOverride_WhenAutoFocusEnabled_OverridesBehavior() {
    // Given: A focus manager with auto-focus enabled
    focusManager.showWindow()

    // When: Manually unfocusing after auto-focus would occur
    let keystroke = createTestKeystroke()
    focusManager.handleKeystroke(keystroke)  // This would auto-focus
    focusManager.unfocusSearchField()  // Manual override

    // Then: Search field should respect manual override
    XCTAssertFalse(
      focusManager.isSearchFieldFocused, "Manual override should take precedence over auto-focus")
  }

  func testManualFocusOverride_TriggersStateChangeCallback() {
    // Given: A focus manager with state change callback
    let expectation = XCTestExpectation(description: "Manual override should trigger state change")
    expectation.expectedFulfillmentCount = 3  // show + auto-focus + manual override

    focusManager.onFocusStateChange = { _, _ in
      expectation.fulfillmentCount += 1
    }

    // When: Performing manual override
    focusManager.showWindow()
    let keystroke = createTestKeystroke()
    focusManager.handleKeystroke(keystroke)
    focusManager.unfocusSearchField()

    // Then: State change callback should be triggered for manual override
    wait(for: [expectation], timeout: 1.0)
    XCTAssertEqual(
      expectation.fulfillmentCount, 3,
      "State change callback should be triggered for manual override")
  }

  // MARK: Edge Cases

  func testRapidStateChanges_HandlesGracefully() {
    // Given: A focus manager

    // When: Rapidly changing states
    focusManager.showWindow()
    focusManager.focusSearchField()
    focusManager.unfocusSearchField()
    focusManager.focusSearchField()
    focusManager.hideWindow()

    // Then: Final state should be consistent
    XCTAssertFalse(focusManager.isWindowVisible, "Window should be hidden after rapid changes")
    XCTAssertFalse(
      focusManager.isSearchFieldFocused, "Search field should be unfocused after rapid changes")
  }

  func testConcurrentKeystrokes_HandlesGracefully() {
    // Given: A visible window with unfocused search field
    focusManager.showWindow()
    XCTAssertFalse(focusManager.isSearchFieldFocused)

    // When: Receiving multiple keystrokes rapidly
    let keystrokes = (0..<5).map { _ in createTestKeystroke() }

    for keystroke in keystrokes {
      focusManager.handleKeystroke(keystroke)
    }

    // Then: Search field should be focused and state should be consistent
    XCTAssertTrue(
      focusManager.isSearchFieldFocused,
      "Search field should be focused after concurrent keystrokes")
    XCTAssertFalse(
      focusManager.isTransitioningFocus,
      "No transition should be in progress after concurrent keystrokes")
  }

  // MARK: - Helper Methods

  private func createTestKeystroke() -> KeystrokeEvent {
    return KeystrokeEvent(
      character: "a",
      keyCode: 0,
      modifierFlags: [],
      timestamp: Date(),
      isPrintable: true
    )
  }
}

// MARK: - Mock Objects

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
