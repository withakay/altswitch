//
//  AppListViewModel.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import AppKit
import Foundation
import Observation
import SwiftUI

/// View model for managing the app list display and interactions
@MainActor
@Observable
final class AppListViewModel {
  // MARK: - Observable Properties

  /// Search results to display
  private(set) var results: [SearchResult] = []

  /// Currently selected index in the results
  var selectedIndex = 0 {
    didSet {
      // Ensure index stays within bounds
      validateSelectedIndex()
    }
  }

  /// Whether search/filtering is in progress
  private(set) var isLoading = false

  /// Current search query
  private(set) var currentQuery = ""

  // MARK: - Dependencies

  private let fuzzySearch: FuzzySearchProtocol

  // MARK: - Private Properties

  @ObservationIgnored
  nonisolated(unsafe) private var searchTask: Task<Void, Never>?
  private let searchDebounceInterval: Duration = .milliseconds(50)

  // MARK: - Computed Properties

  /// The currently selected search result
  var selectedResult: SearchResult? {
    guard selectedIndex >= 0 && selectedIndex < results.count else {
      return nil
    }
    return results[selectedIndex]
  }

  /// Whether there are any results
  var hasResults: Bool {
    !results.isEmpty
  }

  /// Get result at specific index safely
  func result(at index: Int) -> SearchResult? {
    guard index >= 0 && index < results.count else {
      return nil
    }
    return results[index]
  }

  // MARK: - Initialization

  init(fuzzySearch: FuzzySearchProtocol = FuzzySearchService()) {
    self.fuzzySearch = fuzzySearch
  }

  deinit {
    // Cancel search task on cleanup
    searchTask?.cancel()
  }

  // MARK: - Public Methods

  /// Update search results based on query
  func updateSearch(query: String, apps: [AppInfo]) async {
    // Cancel any pending search
    searchTask?.cancel()

    currentQuery = query

    // Don't debounce if query is empty (show all apps immediately)
    if query.isEmpty {
      await performSearch(query: query, apps: apps)
      return
    }

    // Debounce search for better performance
    searchTask = Task { @MainActor in
      isLoading = true

      // Small delay to debounce rapid typing
      try? await Task.sleep(for: searchDebounceInterval)

      guard !Task.isCancelled else {
        isLoading = false
        return
      }

      await performSearch(query: query, apps: apps)
      isLoading = false
    }
  }

  /// Clear search and results
  func clearSearch() {
    searchTask?.cancel()
    currentQuery = ""
    results = []
    selectedIndex = 0
    isLoading = false
  }

  /// Navigate to previous item in the list
  func selectPrevious() {
    guard hasResults else { return }

    if selectedIndex > 0 {
      selectedIndex -= 1
    } else {
      // Wrap around to bottom
      selectedIndex = results.count - 1
    }
  }

  /// Navigate to next item in the list
  func selectNext() {
    guard hasResults else { return }

    if selectedIndex < results.count - 1 {
      selectedIndex += 1
    } else {
      // Wrap around to top
      selectedIndex = 0
    }
  }

  /// Jump to specific index (for Cmd+1-9 shortcuts)
  func selectIndex(_ index: Int) {
    guard index >= 0 && index < results.count else { return }
    selectedIndex = index
  }

  /// Select first result
  func selectFirst() {
    guard hasResults else { return }
    selectedIndex = 0
  }

  /// Select last result
  func selectLast() {
    guard hasResults else { return }
    selectedIndex = results.count - 1
  }

  /// Handle keyboard shortcuts
  func handleKeyboardShortcut(_ keyCode: Int, modifiers: NSEvent.ModifierFlags) -> Bool {
    // Cmd + Number (1-9) for quick selection
    if modifiers.contains(.command) {
      switch keyCode {
      case 18:  // 1
        selectIndex(0)
        return true
      case 19:  // 2
        selectIndex(1)
        return true
      case 20:  // 3
        selectIndex(2)
        return true
      case 21:  // 4
        selectIndex(3)
        return true
      case 23:  // 5
        selectIndex(4)
        return true
      case 22:  // 6
        selectIndex(5)
        return true
      case 26:  // 7
        selectIndex(6)
        return true
      case 28:  // 8
        selectIndex(7)
        return true
      case 25:  // 9
        selectIndex(8)
        return true
      default:
        break
      }
    }

    // Arrow key navigation
    switch keyCode {
    case 126:  // Up arrow
      selectPrevious()
      return true
    case 125:  // Down arrow
      selectNext()
      return true
    case 123:  // Left arrow (same as up for horizontal lists)
      selectPrevious()
      return true
    case 124:  // Right arrow (same as down for horizontal lists)
      selectNext()
      return true
    default:
      break
    }

    // Additional shortcuts with modifiers
    if modifiers.contains(.command) {
      switch keyCode {
      case 126:  // Cmd+Up - go to first
        selectFirst()
        return true
      case 125:  // Cmd+Down - go to last
        selectLast()
        return true
      default:
        break
      }
    }

    return false
  }

  /// Check if an index is currently selected
  func isSelected(_ index: Int) -> Bool {
    selectedIndex == index
  }

  /// Get visual representation for quick select number (1-9)
  func quickSelectNumber(for index: Int) -> String? {
    guard index >= 0 && index < 9 else { return nil }
    return "\(index + 1)"
  }

  // MARK: - Private Methods

  private func performSearch(query: String, apps: [AppInfo]) async {
    let searchResults = await fuzzySearch.search(query, in: apps)

    // Only update if this is still the current query
    guard currentQuery == query else { return }

    results = searchResults
    validateSelectedIndex()
  }

  private func validateSelectedIndex() {
    if results.isEmpty {
      selectedIndex = 0
    } else if selectedIndex >= results.count {
      selectedIndex = results.count - 1
    } else if selectedIndex < 0 {
      selectedIndex = 0
    }
  }
}

// MARK: - Highlighting Support

extension AppListViewModel {
  /// Get attributed string with search highlights
  @MainActor func highlightedName(for result: SearchResult) -> AttributedString {
    var attributedString = AttributedString(result.app.localizedName)

    guard !currentQuery.isEmpty else {
      return attributedString
    }

    // Simple highlight: make matching parts bold
    let lowercasedName = result.app.localizedName.lowercased()
    let lowercasedQuery = currentQuery.lowercased()

    if let range = lowercasedName.range(of: lowercasedQuery) {
      let startIndex = lowercasedName.distance(
        from: lowercasedName.startIndex, to: range.lowerBound)
      let endIndex = startIndex + lowercasedQuery.count

      if let attrRange = Range(
        NSRange(location: startIndex, length: endIndex - startIndex), in: attributedString)
      {
        attributedString[attrRange].font = .system(size: 13, weight: .bold)
      }
    }

    return attributedString
  }
}

// MARK: - Testing Support

#if DEBUG
  extension AppListViewModel {
    /// Create a view model with mock data for testing/preview
    static func mock() -> AppListViewModel {
      let appListViewModel = AppListViewModel()

      // Create some mock results
      let mockApps = [
        AppInfo(
          bundleIdentifier: "com.apple.Safari",
          localizedName: "Safari",
          processIdentifier: 1234,
          icon: NSImage(systemSymbolName: "safari", accessibilityDescription: "Safari")
            ?? NSImage(),
          isActive: true,
          isHidden: false,
          windows: []
        ),
        AppInfo(
          bundleIdentifier: "com.apple.Finder",
          localizedName: "Finder",
          processIdentifier: 1235,
          icon: NSImage(systemSymbolName: "folder", accessibilityDescription: "Finder")
            ?? NSImage(),
          isActive: false,
          isHidden: false,
          windows: []
        ),
        AppInfo(
          bundleIdentifier: "com.microsoft.VSCode",
          localizedName: "Visual Studio Code",
          processIdentifier: 1236,
          icon: NSImage(
            systemSymbolName: "chevron.left.forwardslash.chevron.right",
            accessibilityDescription: "VSCode") ?? NSImage(),
          isActive: false,
          isHidden: false,
          windows: []
        ),
      ]

      appListViewModel.results = mockApps.map { app in
        SearchResult(app: app, score: 1.0, matchedFields: [.name])
      }

      return appListViewModel
    }
  }
#endif
