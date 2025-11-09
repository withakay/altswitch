//
//  KeyboardNavigationTests.swift
//  AltSwitchTests
//
//  Integration tests for keyboard navigation functionality
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import Testing

@testable import AltSwitch

@Suite("Keyboard Navigation Integration")
struct KeyboardNavigationTests {

  @Test("Arrow key navigation through application list")
  func testArrowKeyNavigation() async throws {
    // Arrange
    let keyboardManager = MockKeyboardManager()
    let appList = MockAppListManager()
    let selectionManager = MockSelectionManager()

    // Populate application list
    let testApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Firefox"),
      MockApplication(bundleIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code"),
      MockApplication(bundleIdentifier: "com.apple.finder", displayName: "Finder"),
    ]
    await appList.setApplications(testApps)

    // Act - Navigate with arrow keys
    await keyboardManager.simulateKeyPress(.downArrow)
    await keyboardManager.simulateKeyPress(.downArrow)
    await keyboardManager.simulateKeyPress(.upArrow)

    // Assert - Should track selection correctly
    let selectionHistory = await selectionManager.getSelectionHistory()
    #expect(selectionHistory.count == 3)

    let currentSelection = await selectionManager.getCurrentSelection()
    #expect(currentSelection == 1)

    // Should wrap around at boundaries
    await keyboardManager.simulateKeyPress(.upArrow)  // Should go to top
    let topSelection = await selectionManager.getCurrentSelection()
    #expect(topSelection == 0)

    await keyboardManager.simulateKeyPress(.downArrow)  // Should go back to index 1
    let backToIndex1 = await selectionManager.getCurrentSelection()
    #expect(backToIndex1 == 1)
  }

  @Test("Tab and Shift+Tab navigation")
  func testTabNavigation() async throws {
    // Arrange
    let keyboardManager = MockKeyboardManager()
    let focusManager = MockFocusManager()

    // Set up focusable elements
    let focusableElements = [
      MockFocusableElement(id: "searchBar", type: .search),
      MockFocusableElement(id: "appList", type: .appList),
      MockFocusableElement(id: "settingsButton", type: .button),
    ]
    await focusManager.setFocusableElements(focusableElements)

    // Act - Navigate with Tab
    await keyboardManager.simulateKeyPress(.tab)
    await keyboardManager.simulateKeyPress(.tab)
    await keyboardManager.simulateKeyPress(.tab)

    // Assert - Should cycle through focusable elements
    let focusHistory = await focusManager.getFocusHistory()
    #expect(focusHistory.count == 3)

    let currentFocus = await focusManager.getCurrentFocus()
    #expect(currentFocus?.id == "settingsButton")

    // Act - Navigate with Shift+Tab
    await keyboardManager.simulateKeyPress(.shiftTab)

    // Assert - Should move backwards
    let backFocus = await focusManager.getCurrentFocus()
    #expect(backFocus?.id == "appList")
  }

  @Test("Enter key selection and activation")
  func testEnterKeyActivation() async throws {
    // Arrange
    let keyboardManager = MockKeyboardManager()
    let appList = MockAppListManager()
    let appSwitcher = MockAppSwitcher()

    let testApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Firefox"),
    ]
    await appList.setApplications(testApps)

    // Navigate to second app
    await keyboardManager.simulateKeyPress(.downArrow)

    // Act - Press Enter to activate
    await keyboardManager.simulateKeyPress(.enter)

    // Assert - Should activate selected application
    let activatedApp = await appSwitcher.getLastActivatedApplication()
    #expect(activatedApp?.bundleIdentifier == "com.google.Chrome")

    let activationHistory = await appSwitcher.getActivationHistory()
    #expect(activationHistory.count == 1)
  }

  @Test("Escape key dismissal and cancellation")
  func testEscapeKeyDismissal() async throws {
    // Arrange
    let keyboardManager = MockKeyboardManager()
    let windowManager = MockWindowManager()
    let searchManager = MockSearchManager()

    // Show window and enter search mode
    await windowManager.showWindow()
    await searchManager.startSearch()

    // Assert - Initial state
    #expect(await windowManager.isWindowVisible())
    #expect(await searchManager.isSearching())

    // Act - Press Escape
    await keyboardManager.simulateKeyPress(.escape)

    // Assert - Should exit search mode but keep window open
    #expect(await windowManager.isWindowVisible())
    #expect(!(await searchManager.isSearching()))

    // Act - Press Escape again
    await keyboardManager.simulateKeyPress(.escape)

    // Assert - Should dismiss window
    #expect(!(await windowManager.isWindowVisible()))
  }

  @Test("Command+number quick navigation")
  func testCommandNumberNavigation() async throws {
    // Arrange
    let keyboardManager = MockKeyboardManager()
    let appList = MockAppListManager()
    let appSwitcher = MockAppSwitcher()

    let testApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Firefox"),
      MockApplication(bundleIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code"),
      MockApplication(bundleIdentifier: "com.apple.finder", displayName: "Finder"),
      MockApplication(bundleIdentifier: "com.apple.mail", displayName: "Mail"),
      MockApplication(bundleIdentifier: "com.apple.music", displayName: "Music"),
      MockApplication(bundleIdentifier: "com.apple.photos", displayName: "Photos"),
      MockApplication(bundleIdentifier: "com.apple.messages", displayName: "Messages"),
      MockApplication(bundleIdentifier: "com.apple.calendar", displayName: "Calendar"),
    ]
    await appList.setApplications(testApps)

    // Test Command+number shortcuts
    let testCases = [
      (.command + "1", "com.apple.Safari"),
      (.command + "3", "com.mozilla.firefox"),
      (.command + "5", "com.apple.finder"),
      (.command + "9", "com.apple.messages"),
    ]

    for (keyCombo, expectedBundleId) in testCases {
      // Act - Press Command+number
      await keyboardManager.simulateKeyPress(keyCombo)

      // Assert - Should activate corresponding application
      let activatedApp = await appSwitcher.getLastActivatedApplication()
      #expect(activatedApp?.bundleIdentifier == expectedBundleId)

      // Reset for next test
      await appSwitcher.clearActivationHistory()
    }
  }

  @Test("Keyboard navigation with search filtering")
  func testKeyboardNavigationWithSearch() async throws {
    // Arrange
    let keyboardManager = MockKeyboardManager()
    let appList = MockAppListManager()
    let searchManager = MockSearchManager()
    let selectionManager = MockSelectionManager()

    let testApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Firefox"),
      MockApplication(bundleIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code"),
      MockApplication(bundleIdentifier: "com.apple.finder", displayName: "Finder"),
    ]
    await appList.setApplications(testApps)

    // Act - Start search and type "c"
    await searchManager.startSearch()
    await keyboardManager.simulateKeyPress("c")

    // Assert - Should filter apps
    let filteredApps = await searchManager.getFilteredApplications()
    #expect(filteredApps.count == 2)
    #expect(filteredApps.contains { $0.displayName.contains("Chrome") })
    #expect(filteredApps.contains { $0.displayName.contains("Code") })

    // Act - Navigate through filtered results
    await keyboardManager.simulateKeyPress(.downArrow)
    await keyboardManager.simulateKeyPress(.downArrow)

    // Assert - Should navigate within filtered results
    let currentSelection = await selectionManager.getCurrentSelection()
    #expect(currentSelection == 1)

    // Act - Clear search
    await keyboardManager.simulateKeyPress(.escape)

    // Assert - Should show all apps again
    let allApps = await searchManager.getFilteredApplications()
    #expect(allApps.count == testApps.count)
  }

  @Test("Keyboard navigation performance and responsiveness")
  func testKeyboardNavigationPerformance() async throws {
    // Arrange
    let keyboardManager = MockKeyboardManager()
    let appList = MockAppListManager()
    let selectionManager = MockSelectionManager()

    // Create large application list
    let largeAppList = (1...50).map { i in
      MockApplication(
        bundleIdentifier: "com.test.App\(i)",
        displayName: "Test Application \(i)"
      )
    }
    await appList.setApplications(largeAppList)

    // Test rapid key presses
    let keyPresses = Array(repeating: .downArrow, count: 20)

    // Act - Simulate rapid key presses
    let startTime = Date()
    for keyPress in keyPresses {
      await keyboardManager.simulateKeyPress(keyPress)
    }
    let totalTime = Date().timeIntervalSince(startTime)

    // Assert - Should handle rapid input efficiently
    #expect(totalTime < 0.1)

    let finalSelection = await selectionManager.getCurrentSelection()
    #expect(finalSelection == 19)

    // Test individual key response time
    for i in 1...10 {
      let keyStartTime = Date()
      await keyboardManager.simulateKeyPress(.upArrow)
      let keyResponseTime = Date().timeIntervalSince(keyStartTime)

      #expect(keyResponseTime < 0.01)
    }
  }
}

// MARK: - Mock Classes for Testing

private actor MockKeyboardManager {
  private var keyPressHistory: [String] = []

  func simulateKeyPress(_ key: String) async {
    keyPressHistory.append(key)

    // Simulate key processing delay
    try? await Task.sleep(nanoseconds: 100_000)  // 0.1ms

    // Route key to appropriate handler based on key type
    if key == MockKey.downArrow || key == MockKey.upArrow {
      await MockSelectionManager.shared.handleArrowKey(key)
    } else if key == MockKey.tab || key == MockKey.shiftTab {
      await MockFocusManager.shared.handleTabKey(key)
    } else if key == MockKey.enter {
      await MockAppSwitcher.shared.handleEnterKey()
    } else if key == MockKey.escape {
      await MockWindowManager.shared.handleEscapeKey()
    } else if key.hasPrefix(MockKey.command) {
      await MockAppSwitcher.shared.handleCommandNumberKey(key)
    } else {
      await MockSearchManager.shared.handleSearchKey(key)
    }
  }

  func getKeyPressHistory() async -> [String] {
    return keyPressHistory
  }
}

private actor MockAppListManager {
  private var applications: [MockApplication] = []

  func setApplications(_ apps: [MockApplication]) async {
    applications = apps
    await MockSelectionManager.shared.setApplicationCount(apps.count)
  }

  func getApplications() async -> [MockApplication] {
    return applications
  }
}

private actor MockSelectionManager {
  static let shared = MockSelectionManager()
  private var currentSelection = 0
  private var selectionHistory: [Int] = []
  private var applicationCount = 0

  func setApplicationCount(_ count: Int) async {
    applicationCount = count
  }

  func handleArrowKey(_ key: String) async {
    if key == MockKey.downArrow {
      currentSelection = (currentSelection + 1) % applicationCount
    } else if key == MockKey.upArrow {
      currentSelection = (currentSelection - 1 + applicationCount) % applicationCount
    }
    selectionHistory.append(currentSelection)
  }

  func getCurrentSelection() async -> Int {
    return currentSelection
  }

  func getSelectionHistory() async -> [Int] {
    return selectionHistory
  }
}

private actor MockFocusManager {
  static let shared = MockFocusManager()
  private var focusableElements: [MockFocusableElement] = []
  private var currentFocusIndex = 0
  private var focusHistory: [String] = []

  func setFocusableElements(_ elements: [MockFocusableElement]) async {
    focusableElements = elements
  }

  func handleTabKey(_ key: String) async {
    if key == MockKey.tab {
      currentFocusIndex = (currentFocusIndex + 1) % focusableElements.count
    } else if key == MockKey.shiftTab {
      currentFocusIndex =
        (currentFocusIndex - 1 + focusableElements.count) % focusableElements.count
    }

    if let currentElement = focusableElements[safe: currentFocusIndex] {
      focusHistory.append(currentElement.id)
    }
  }

  func getCurrentFocus() async -> MockFocusableElement? {
    return focusableElements[safe: currentFocusIndex]
  }

  func getFocusHistory() async -> [String] {
    return focusHistory
  }
}

private actor MockAppSwitcher {
  static let shared = MockAppSwitcher()
  private var activationHistory: [MockApplication] = []
  private var lastActivatedApp: MockApplication?

  func handleEnterKey() async {
    let selectedIndex = await MockSelectionManager.shared.getCurrentSelection()
    let apps = await MockAppListManager.shared.getApplications()

    if let selectedApp = apps[safe: selectedIndex] {
      lastActivatedApp = selectedApp
      activationHistory.append(selectedApp)
    }
  }

  func handleCommandNumberKey(_ key: String) async {
    guard key.hasPrefix(MockKey.command) else { return }

    let numberString = key.replacingOccurrences(of: MockKey.command, with: "")
    guard let number = Int(numberString), number >= 1 && number <= 9 else { return }

    let appIndex = number - 1
    let apps = await MockAppListManager.shared.getApplications()

    if let selectedApp = apps[safe: appIndex] {
      lastActivatedApp = selectedApp
      activationHistory.append(selectedApp)
    }
  }

  func getLastActivatedApplication() async -> MockApplication? {
    return lastActivatedApp
  }

  func getActivationHistory() async -> [MockApplication] {
    return activationHistory
  }

  func clearActivationHistory() async {
    activationHistory.removeAll()
    lastActivatedApp = nil
  }
}

private actor MockWindowManager {
  static let shared = MockWindowManager()
  private var isWindowVisible = false

  func showWindow() async {
    isWindowVisible = true
  }

  func hideWindow() async {
    isWindowVisible = false
  }

  func isWindowVisible() async -> Bool {
    return isWindowVisible
  }

  func handleEscapeKey() async {
    if isWindowVisible {
      hideWindow()
    }
  }
}

private actor MockSearchManager {
  static let shared = MockSearchManager()
  private var isSearching = false
  private var searchQuery = ""
  private var allApplications: [MockApplication] = []

  func startSearch() async {
    isSearching = true
    searchQuery = ""
    allApplications = await MockAppListManager.shared.getApplications()
  }

  func handleSearchKey(_ key: String) async {
    guard isSearching else { return }

    if key == MockKey.escape {
      isSearching = false
      searchQuery = ""
    } else {
      searchQuery += key
    }
  }

  func isSearching() async -> Bool {
    return isSearching
  }

  func getFilteredApplications() async -> [MockApplication] {
    guard !searchQuery.isEmpty else {
      return isSearching ? allApplications : []
    }

    return allApplications.filter { app in
      app.displayName.lowercased().contains(searchQuery.lowercased())
    }
  }
}

// MARK: - Supporting Test Types

private struct MockApplication: Equatable, Sendable {
  let bundleIdentifier: String
  let displayName: String
}

private struct MockFocusableElement: Equatable, Sendable {
  let id: String
  let type: FocusableType
}

private enum FocusableType: Sendable {
  case search
  case appList
  case button
}

private enum MockKey {
  static let downArrow = "↓"
  static let upArrow = "↑"
  static let tab = "⇥"
  static let shiftTab = "⇧⇥"
  static let enter = "⏎"
  static let escape = "⎋"
  static let command = "⌘"
}

// MARK: - Array Extension

extension Array {
  subscript(safe index: Int) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}
