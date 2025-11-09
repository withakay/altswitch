import XCTest

@testable import AltSwitch

/// Integration tests for rapid typing performance
///
/// Requirements from quickstart.md:
/// - Rapid typing sequences should be handled without dropped characters
/// - Performance should remain responsive during fast typing
/// - System should maintain <10ms latency requirement
/// - No character loss during rapid typing sessions
final class RapidTypingTests: XCTestCase {

  // MARK: - Test Properties

  private var keystrokeHandler: any KeystrokeHandlerProtocol!
  private var focusManager: any FocusManagerProtocol!
  private var searchBox: any SearchBoxIntegrationProtocol!
  private var mainWindow: MainWindow!
  private var keystrokeTimestamps: [Date] = []
  private var processingTimes: [TimeInterval] = []

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()
    setupTestComponents()
    keystrokeTimestamps = []
    processingTimes = []
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

  // MARK: Basic Rapid Typing

  func testRapidTyping_TenCharactersPerSecond_HandlesCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()
    XCTAssertTrue(mainWindow.isVisible)

    let expectation = XCTestExpectation(description: "All characters should be processed")
    expectation.expectedFulfillmentCount = 10

    searchBox.onTextChange = { text in
      if text.count == 10 {
        expectation.fulfill()
      }
    }

    // When: Typing 10 characters at 10 chars/sec (100ms intervals)
    let characters = Array("abcdefghij")
    for (index, character) in characters.enumerated() {
      let delay = TimeInterval(index) * 0.1  // 100ms intervals

      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.simulateKeystroke(String(character))
      }
    }

    // Then: All characters should be processed correctly
    wait(for: [expectation], timeout: 2.0)
    XCTAssertEqual(searchBox.text, "abcdefghij", "All 10 characters should appear in correct order")
    XCTAssertTrue(searchBox.isFocused, "Search box should remain focused")
  }

  func testRapidTyping_TwentyCharactersPerSecond_HandlesCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    let expectation = XCTestExpectation(description: "All characters should be processed")
    expectation.expectedFulfillmentCount = 20

    searchBox.onTextChange = { text in
      if text.count == 20 {
        expectation.fulfill()
      }
    }

    // When: Typing 20 characters at 20 chars/sec (50ms intervals)
    let characters = Array("abcdefghijklmnopqrst")
    for (index, character) in characters.enumerated() {
      let delay = TimeInterval(index) * 0.05  // 50ms intervals

      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.simulateKeystroke(String(character))
      }
    }

    // Then: All characters should be processed correctly
    wait(for: [expectation], timeout: 2.0)
    XCTAssertEqual(
      searchBox.text, "abcdefghijklmnopqrst", "All 20 characters should appear in correct order")
  }

  func testRapidTyping_FiftyCharactersPerSecond_HandlesCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    let expectation = XCTestExpectation(description: "All characters should be processed")
    expectation.expectedFulfillmentCount = 50

    searchBox.onTextChange = { text in
      if text.count == 50 {
        expectation.fulfill()
      }
    }

    // When: Typing 50 characters at 50 chars/sec (20ms intervals)
    let characters = Array(String(repeating: "a", count: 50))
    for (index, character) in characters.enumerated() {
      let delay = TimeInterval(index) * 0.02  // 20ms intervals

      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.simulateKeystroke(String(character))
      }
    }

    // Then: All characters should be processed correctly
    wait(for: [expectation], timeout: 2.0)
    XCTAssertEqual(
      searchBox.text, String(repeating: "a", count: 50), "All 50 characters should appear")
  }

  // MARK: Performance Requirements

  func testRapidTyping_LessThanTenMsLatency_MaintainsPerformance() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    let expectation = XCTestExpectation(
      description: "All characters should be processed within latency")
    expectation.expectedFulfillmentCount = 10

    var maxLatency: TimeInterval = 0

    searchBox.onTextChange = { [weak self] text in
      if text.count == 10 {
        expectation.fulfill()
      }
    }

    // When: Typing 10 characters rapidly and measuring latency
    let characters = Array("abcdefghij")
    for (index, character) in characters.enumerated() {
      let delay = TimeInterval(index) * 0.05  // 50ms intervals

      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        let startTime = Date()
        self?.simulateKeystroke(String(character))
        let endTime = Date()
        let latency = endTime.timeIntervalSince(startTime)

        self?.processingTimes.append(latency)
        maxLatency = max(maxLatency, latency)
      }
    }

    // Then: All characters should be processed with <10ms latency
    wait(for: [expectation], timeout: 2.0)
    XCTAssertEqual(searchBox.text, "abcdefghij", "All characters should appear")
    XCTAssertLessThan(maxLatency, 0.01, "Maximum latency should be less than 10ms")

    // Log performance metrics
    let avgLatency = processingTimes.reduce(0, +) / Double(processingTimes.count)
    print("Average latency: \(avgLatency * 1000)ms")
    print("Maximum latency: \(maxLatency * 1000)ms")
  }

  func testRapidTyping_BurstTyping_HandlesCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    let expectation = XCTestExpectation(description: "Burst typing should be handled")
    expectation.expectedFulfillmentCount = 5  // 5 bursts

    var burstCount = 0
    searchBox.onTextChange = { text in
      if text.count == 10 * (burstCount + 1) {
        burstCount += 1
        expectation.fulfill()
      }
    }

    // When: Typing in bursts (rapid typing followed by pauses)
    let bursts = [
      "abcdefghij",  // First burst
      "klmnopqrst",  // Second burst
      "uvwxyzabcd",  // Third burst
      "efghijklmn",  // Fourth burst
      "opqrstuvwx",  // Fifth burst
    ]

    for (burstIndex, burst) in bursts.enumerated() {
      let burstDelay = TimeInterval(burstIndex) * 0.5  // 500ms between bursts

      DispatchQueue.main.asyncAfter(deadline: .now() + burstDelay) {
        // Type burst rapidly
        for (charIndex, character) in burst.enumerated() {
          let charDelay = TimeInterval(charIndex) * 0.01  // 10ms within burst
          DispatchQueue.main.asyncAfter(deadline: .now() + charDelay) {
            self.simulateKeystroke(String(character))
          }
        }
      }
    }

    // Then: All bursts should be processed correctly
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(
      searchBox.text, "abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwx",
      "All bursts should be concatenated correctly")
  }

  // MARK: Character Loss Prevention

  func testRapidTyping_NoCharacterLoss_GuaranteesAllCharacters() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    let expectation = XCTestExpectation(description: "No characters should be lost")
    expectation.expectedFulfillmentCount = 100

    searchBox.onTextChange = { text in
      if text.count == 100 {
        expectation.fulfill()
      }
    }

    // When: Typing 100 characters rapidly
    let characters = Array(String(repeating: "x", count: 100))
    for (index, character) in characters.enumerated() {
      let delay = TimeInterval(index) * 0.01  // 10ms intervals (100 chars/sec)

      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.simulateKeystroke(String(character))
      }
    }

    // Then: No characters should be lost
    wait(for: [expectation], timeout: 3.0)
    XCTAssertEqual(
      searchBox.text, String(repeating: "x", count: 100),
      "No characters should be lost during rapid typing")
    XCTAssertEqual(searchBox.text.count, 100, "Exactly 100 characters should be present")
  }

  func testRapidTyping_MixedCharacters_NoCharacterLoss() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    let expectation = XCTest.Expectation(description: "Mixed characters should not be lost")
    expectation.expectedFulfillmentCount = 1

    let targetText = "The quick brown fox jumps over the lazy dog 1234567890 !@#$%^&*()"

    searchBox.onTextChange = { text in
      if text == targetText {
        expectation.fulfill()
      }
    }

    // When: Typing mixed characters rapidly
    let characters = Array(targetText)
    for (index, character) in characters.enumerated() {
      let delay = TimeInterval(index) * 0.015  // 15ms intervals

      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.simulateKeystroke(String(character))
      }
    }

    // Then: All mixed characters should be preserved
    wait(for: [expectation], timeout: 3.0)
    XCTAssertEqual(searchBox.text, targetText, "All mixed characters should be preserved")
  }

  // MARK: System Load Simulation

  func testRapidTyping_WithSystemLoad_MaintainsPerformance() {
    // Given: AltSwitch window is visible and system is under load
    mainWindow.show()

    // Simulate system load by creating background tasks
    let backgroundQueue = DispatchQueue.global(qos: .background)
    let loadGroup = DispatchGroup()

    // Create background load
    for i in 0..<10 {
      loadGroup.enter()
      backgroundQueue.async {
        // Simulate CPU load
        var result = 0
        for j in 0..<1_000_000 {
          result += i * j
        }
        loadGroup.leave()
      }
    }

    let expectation = XCTestExpectation(description: "Typing should work under system load")
    expectation.expectedFulfillmentCount = 20

    searchBox.onTextChange = { text in
      if text.count == 20 {
        expectation.fulfill()
      }
    }

    // When: Typing while system is under load
    let characters = Array("abcdefghijklmnopqrst")
    for (index, character) in characters.enumerated() {
      let delay = TimeInterval(index) * 0.03  // 30ms intervals

      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.simulateKeystroke(String(character))
      }
    }

    // Then: Typing should still work correctly
    wait(for: [expectation], timeout: 3.0)
    XCTAssertEqual(searchBox.text, "abcdefghijklmnopqrst", "Typing should work under system load")

    // Wait for background tasks to complete
    loadGroup.wait()
  }

  // MARK: Memory and Resource Management

  func testRapidTyping_LongSequence_HandlesMemoryEfficiently() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    let expectation = XCTestExpectation(description: "Long sequence should be handled")
    expectation.expectedFulfillmentCount = 1

    let longText = String(repeating: "a", count: 1000)  // 1000 characters

    searchBox.onTextChange = { text in
      if text == longText {
        expectation.fulfill()
      }
    }

    // When: Typing very long sequence rapidly
    let characters = Array(longText)
    for (index, character) in characters.enumerated() {
      let delay = TimeInterval(index) * 0.005  // 5ms intervals (200 chars/sec)

      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.simulateKeystroke(String(character))
      }
    }

    // Then: Long sequence should be handled without memory issues
    wait(for: [expectation], timeout: 8.0)
    XCTAssertEqual(searchBox.text, longText, "Long sequence should be handled correctly")
    XCTAssertEqual(searchBox.text.count, 1000, "All 1000 characters should be present")
  }

  func testRapidTyping_MultipleSessions_HandlesCorrectly() {
    // Given: AltSwitch window is visible
    mainWindow.show()

    let expectation = XCTestExpectation(description: "Multiple typing sessions should work")
    expectation.expectedFulfillmentCount = 3  // 3 sessions

    var sessionCount = 0
    searchBox.onTextChange = { [weak self] text in
      if text.count == 10 * (sessionCount + 1) {
        sessionCount += 1
        expectation.fulfill()
      }
    }

    // When: Performing multiple rapid typing sessions
    let sessions = [
      "abcdefghij",  // Session 1
      "klmnopqrst",  // Session 2
      "uvwxyzabcd",  // Session 3
    ]

    for (sessionIndex, session) in sessions.enumerated() {
      let sessionDelay = TimeInterval(sessionIndex) * 1.0  // 1 second between sessions

      DispatchQueue.main.asyncAfter(deadline: .now() + sessionDelay) {
        // Clear text and start new session
        self?.searchBox.clearText()

        // Type session rapidly
        for (charIndex, character) in session.enumerated() {
          let charDelay = TimeInterval(charIndex) * 0.02  // 20ms within session
          DispatchQueue.main.asyncAfter(deadline: .now() + charDelay) {
            self?.simulateKeystroke(String(character))
          }
        }
      }
    }

    // Then: All sessions should be handled correctly
    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(searchBox.text, "uvwxyzabcd", "Final session text should be correct")
  }

  // MARK: - Helper Methods

  private func setupTestComponents() {
    keystrokeHandler = createKeystrokeHandler()
    focusManager = createFocusManager()
    searchBox = createSearchBox()
    mainWindow = createMainWindow()

    // Connect components for integration testing
    keystrokeHandler.onKeystroke = { [weak self] keystroke in
      self?.keystrokeTimestamps.append(Date())
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

extension RapidTypingTests {
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
