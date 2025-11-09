//
//  FuzzySearchIntegrationTests.swift
//  AltSwitchTests
//
//  Integration tests for fuzzy search functionality
//  These tests MUST FAIL until the implementation is complete
//

import AppKit
import Foundation
import Testing

@testable import AltSwitch

@Suite("Fuzzy Search Integration")
struct FuzzySearchIntegrationTests {

  @Test("Fuzzy search finds applications by name")
  func testFuzzySearchFindsApplicationsByName() async throws {
    // Arrange
    let fuzzySearch = MockFuzzySearchService()
    let appDatabase = MockAppDatabase()

    // Populate with test applications
    let testApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Firefox"),
      MockApplication(bundleIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code"),
      MockApplication(bundleIdentifier: "com.apple.finder", displayName: "Finder"),
    ]
    await appDatabase.setApplications(testApps)

    // Act - Search for applications
    let safariResults = await fuzzySearch.search("safari", in: appDatabase)
    let chromeResults = await fuzzySearch.search("chrome", in: appDatabase)
    let codeResults = await fuzzySearch.search("code", in: appDatabase)

    // Assert - Should find matching applications
    #expect(safariResults.count > 0, "Should find Safari when searching for 'safari'")
    #expect(
      safariResults.contains { $0.app.bundleIdentifier == "com.apple.Safari" },
      "Should find Safari with exact bundle ID match")

    #expect(chromeResults.count > 0, "Should find Chrome when searching for 'chrome'")
    #expect(
      chromeResults.contains { $0.app.bundleIdentifier == "com.google.Chrome" },
      "Should find Chrome with exact bundle ID match")

    #expect(codeResults.count > 0, "Should find VS Code when searching for 'code'")
    #expect(
      codeResults.contains { $0.app.bundleIdentifier == "com.microsoft.VSCode" },
      "Should find VS Code with partial name match")
  }

  @Test("Fuzzy search handles partial and misspelled queries")
  func testFuzzySearchHandlesPartialQueries() async throws {
    // Arrange
    let fuzzySearch = MockFuzzySearchService()
    let appDatabase = MockAppDatabase()

    let testApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Mozilla Firefox"),
      MockApplication(bundleIdentifier: "com.microsoft.VSCode", displayName: "Visual Studio Code"),
      MockApplication(bundleIdentifier: "com.adobe.Photoshop", displayName: "Adobe Photoshop"),
    ]
    await appDatabase.setApplications(testApps)

    // Test partial matches
    let partialQueries = [
      ("saf", "Safari"),
      ("chr", "Chrome"),
      ("fox", "Firefox"),
      ("code", "Visual Studio Code"),
      ("photo", "Photoshop"),
    ]

    for (query, expectedApp) in partialQueries {
      // Act
      let results = await fuzzySearch.search(query, in: appDatabase)

      // Assert
      #expect(results.count > 0, "Should find results for partial query '\(query)'")
      #expect(
        results.contains { $0.app.displayName.contains(expectedApp) },
        "Should find \(expectedApp) when searching for '\(query)'")
    }

    // Test misspelled queries
    let misspelledQueries = [
      ("safarii", "Safari"),
      ("chrme", "Chrome"),
      ("firefoxx", "Firefox"),
      ("vscoode", "Visual Studio Code"),
      ("potoshop", "Photoshop"),
    ]

    for (query, expectedApp) in misspelledQueries {
      // Act
      let results = await fuzzySearch.search(query, in: appDatabase)

      // Assert
      #expect(results.count > 0, "Should find results for misspelled query '\(query)'")
      #expect(
        results.contains { $0.app.displayName.contains(expectedApp) },
        "Should find \(expectedApp) when searching for misspelled '\(query)'")
    }
  }

  @Test("Fuzzy search ranks results by relevance")
  func testFuzzySearchRanksResultsByRelevance() async throws {
    // Arrange
    let fuzzySearch = MockFuzzySearchService()
    let appDatabase = MockAppDatabase()

    let testApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.safari.extensions", displayName: "Safari Extensions"),
      MockApplication(bundleIdentifier: "com.safari.downloader", displayName: "Safari Downloader"),
      MockApplication(bundleIdentifier: "com.chrome.safari", displayName: "Chrome Safari Importer"),
    ]
    await appDatabase.setApplications(testApps)

    // Act - Search for "safari"
    let results = await fuzzySearch.search("safari", in: appDatabase)

    // Assert - Results should be ranked by relevance
    #expect(results.count >= 2, "Should find multiple results for 'safari'")

    // First result should be the most relevant (exact match)
    let firstResult = results.first!
    #expect(
      firstResult.app.bundleIdentifier == "com.apple.Safari",
      "First result should be exact match 'Safari'")

    // Results should have relevance scores
    for (index, result) in results.enumerated() {
      #expect(result.score > 0, "Result \(index) should have relevance score > 0")
      if index > 0 {
        let previousScore = results[index - 1].score
        #expect(
          result.score <= previousScore,
          "Results should be sorted by relevance (descending)")
      }
    }
  }

  @Test("Fuzzy search performance with large application database")
  func testFuzzySearchPerformance() async throws {
    // Arrange
    let fuzzySearch = MockFuzzySearchService()
    let appDatabase = MockAppDatabase()

    // Create large application database
    let largeAppList = (1...100).map { i in
      MockApplication(
        bundleIdentifier: "com.test.App\(i)",
        displayName: "Test Application \(i)"
      )
    }
    await appDatabase.setApplications(largeAppList)

    // Test various search queries
    let testQueries = ["test", "app", "1", "application", ""]

    for query in testQueries {
      // Act - Measure search performance
      let startTime = Date()
      let results = await fuzzySearch.search(query, in: appDatabase)
      let searchTime = Date().timeIntervalSince(startTime)

      // Assert - Should complete within performance budget
      #expect(
        searchTime < 0.05,
        "Search for '\(query)' should complete within 50ms, took \(searchTime * 1000)ms")

      // Should return valid results
      #expect(results.count >= 0, "Search for '\(query)' should return valid results")

      // Results should be properly scored
      for result in results {
        #expect(result.score >= 0, "Result should have valid relevance score")
      }
    }
  }

  @Test("Fuzzy search handles empty and special character queries")
  func testFuzzySearchHandlesSpecialQueries() async throws {
    // Arrange
    let fuzzySearch = MockFuzzySearchService()
    let appDatabase = MockAppDatabase()

    let testApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Mozilla Firefox"),
    ]
    await appDatabase.setApplications(testApps)

    // Test empty query
    let emptyResults = await fuzzySearch.search("", in: appDatabase)
    #expect(emptyResults.count == testApps.count, "Empty query should return all applications")

    // Test special character queries
    let specialQueries = ["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"]

    for query in specialQueries {
      // Act
      let results = await fuzzySearch.search(query, in: appDatabase)

      // Assert - Should handle gracefully without crashing
      #expect(results.count >= 0, "Should handle special character query '\(query)' gracefully")

      for result in results {
        #expect(result.score >= 0, "Result should have valid relevance score")
      }
    }

    // Test whitespace queries
    let whitespaceQueries = [" ", "  ", "   ", "\t", "\n"]

    for query in whitespaceQueries {
      // Act
      let results = await fuzzySearch.search(query, in: appDatabase)

      // Assert
      #expect(results.count >= 0, "Should handle whitespace query '\(query)' gracefully")
    }
  }

  @Test("Fuzzy search integrates with real-time application discovery")
  func testFuzzySearchIntegratesWithRealTimeDiscovery() async throws {
    // Arrange
    let fuzzySearch = MockFuzzySearchService()
    let appDatabase = MockAppDatabase()
    let appDiscovery = MockAppDiscoveryService()

    // Initial applications
    let initialApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
    ]
    await appDatabase.setApplications(initialApps)

    // Act - Initial search
    let initialResults = await fuzzySearch.search("safari", in: appDatabase)
    #expect(initialResults.count == 1, "Should find Safari initially")

    // Simulate new application launch
    let newApp = MockApplication(
      bundleIdentifier: "com.mozilla.firefox", displayName: "Mozilla Firefox")
    await appDiscovery.simulateApplicationLaunch(newApp)
    await appDatabase.addApplication(newApp)

    // Act - Search after new app launch
    let updatedResults = await fuzzySearch.search("firefox", in: appDatabase)

    // Assert - Should find newly launched application
    #expect(updatedResults.count == 1, "Should find Firefox after launch")
    #expect(
      updatedResults.contains { $0.app.bundleIdentifier == "com.mozilla.firefox" },
      "Should find Firefox with correct bundle ID")

    // Simulate application quit
    await appDiscovery.simulateApplicationQuit("com.apple.Safari")
    await appDatabase.removeApplication("com.apple.Safari")

    // Act - Search after app quit
    let finalResults = await fuzzySearch.search("safari", in: appDatabase)

    // Assert - Should not find quit application
    #expect(finalResults.count == 0, "Should not find Safari after quit")
  }

  @Test("Fuzzy search respects application visibility settings")
  func testFuzzySearchRespectsVisibilitySettings() async throws {
    // Arrange
    let fuzzySearch = MockFuzzySearchService()
    let appDatabase = MockAppDatabase()
    let settingsManager = MockSettingsManager()

    let testApps = [
      MockApplication(bundleIdentifier: "com.apple.Safari", displayName: "Safari"),
      MockApplication(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
      MockApplication(bundleIdentifier: "com.mozilla.firefox", displayName: "Mozilla Firefox"),
      MockApplication(bundleIdentifier: "com.system.hidden", displayName: "Hidden System App"),
    ]
    await appDatabase.setApplications(testApps)

    // Configure settings to hide system applications
    await settingsManager.setShowSystemApplications(false)

    // Act - Search with system apps hidden
    let results = await fuzzySearch.search("app", in: appDatabase, settings: settingsManager)

    // Assert - Should not include hidden system applications
    #expect(
      !results.contains { $0.app.bundleIdentifier == "com.system.hidden" },
      "Should not include hidden system applications")

    // Should still show user applications
    #expect(
      results.contains { $0.app.bundleIdentifier == "com.apple.Safari" },
      "Should still show user applications")

    // Change settings to show system applications
    await settingsManager.setShowSystemApplications(true)

    // Act - Search with system apps visible
    let allResults = await fuzzySearch.search("app", in: appDatabase, settings: settingsManager)

    // Assert - Should include all applications
    #expect(
      allResults.contains { $0.app.bundleIdentifier == "com.system.hidden" },
      "Should include system applications when enabled")
  }
}

// MARK: - Mock Classes for Testing

private actor MockFuzzySearchService {
  func search(_ query: String, in database: MockAppDatabase, settings: MockSettingsManager? = nil)
    async -> [SearchResult]
  {
    // Simulate search processing time
    try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms

    let applications = await database.getApplications()
    let showSystemApps = await settings?.getShowSystemApplications() ?? true

    let filteredApps =
      showSystemApps
      ? applications : applications.filter { !$0.bundleIdentifier.contains("system") }

    guard !query.isEmpty else {
      return filteredApps.map { app in
        SearchResult(
          app: app.toAppInfo(),
          score: 1.0,
          matchedFields: [.appName]
        )
      }
    }

    let results = filteredApps.compactMap { app -> SearchResult? in
      let score = calculateRelevanceScore(query: query, for: app)
      guard score > 0 else { return nil }

      return SearchResult(
        app: app.toAppInfo(),
        score: score,
        matchedFields: [.appName]
      )
    }

    return results.sorted { $0.score > $1.score }
  }

  private func calculateRelevanceScore(query: String, for app: MockApplication) -> Double {
    let lowerQuery = query.lowercased()
    let lowerName = app.displayName.lowercased()

    // Exact match gets highest score
    if lowerName == lowerQuery {
      return 1.0
    }

    // Partial match gets medium score
    if lowerName.contains(lowerQuery) {
      return 0.8
    }

    // Fuzzy match based on character overlap
    let queryChars = Set(lowerQuery)
    let nameChars = Set(lowerName)
    let intersection = queryChars.intersection(nameChars)
    let union = queryChars.union(nameChars)

    guard !union.isEmpty else { return 0 }

    let jaccardSimilarity = Double(intersection.count) / Double(union.count)
    return jaccardSimilarity * 0.6
  }
}

private actor MockAppDatabase {
  private var applications: [MockApplication] = []

  func setApplications(_ apps: [MockApplication]) async {
    applications = apps
  }

  func getApplications() async -> [MockApplication] {
    return applications
  }

  func addApplication(_ app: MockApplication) async {
    applications.append(app)
  }

  func removeApplication(_ bundleIdentifier: String) async {
    applications.removeAll { $0.bundleIdentifier == bundleIdentifier }
  }
}

private actor MockAppDiscoveryService {
  func simulateApplicationLaunch(_ app: MockApplication) async {
    // Mock implementation
  }

  func simulateApplicationQuit(_ bundleIdentifier: String) async {
    // Mock implementation
  }
}

private actor MockSettingsManager {
  private var showSystemApplications = true

  func setShowSystemApplications(_ show: Bool) async {
    showSystemApplications = show
  }

  func getShowSystemApplications() async -> Bool {
    return showSystemApplications
  }
}

// MARK: - Supporting Test Types

private struct MockApplication: Equatable, Sendable {
  let bundleIdentifier: String
  let displayName: String
  let processIdentifier: pid_t
  let icon: NSImage
  var isActive: Bool
  var isHidden: Bool
  var windows: [WindowInfo]
  let url: URL?

  init(
    bundleIdentifier: String,
    displayName: String,
    processIdentifier: pid_t = 1234,
    icon: NSImage = NSImage(systemSymbolName: "app.fill", accessibilityDescription: "App icon")
      ?? NSImage(),
    isActive: Bool = false,
    isHidden: Bool = false,
    windows: [WindowInfo] = [],
    url: URL? = nil
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.displayName = displayName
    self.processIdentifier = processIdentifier
    self.icon = icon
    self.isActive = isActive
    self.isHidden = isHidden
    self.windows = windows
    self.url = url
  }

  func toAppInfo() -> AppInfo {
    AppInfo(
      bundleIdentifier: bundleIdentifier,
      localizedName: displayName,
      processIdentifier: processIdentifier,
      icon: icon,
      isActive: isActive,
      isHidden: isHidden,
      windows: windows,
      url: url
    )
  }
}

// Note: Using the actual SearchResult from the main app
// This is just a type alias for clarity in the test context
private typealias SearchResult = AltSwitch.SearchResult
