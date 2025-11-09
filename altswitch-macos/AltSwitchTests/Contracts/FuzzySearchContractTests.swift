//
//  FuzzySearchContractTests.swift
//  AltSwitchTests
//
//  Contract tests for the FuzzySearchService
//

import AppKit
import Foundation
import Testing

@testable import AltSwitch

@Suite("Fuzzy Search Contract")
struct FuzzySearchContractTests {

  // Test data
  var testApps: [AppInfo] {
    [
      TestFixtures.app(bundleIdentifier: "com.apple.Safari", name: "Safari", pid: 1001),
      TestFixtures.app(bundleIdentifier: "com.google.Chrome", name: "Google Chrome", pid: 1002),
      TestFixtures.app(
        bundleIdentifier: "com.apple.systempreferences", name: "System Settings", pid: 1003),
      TestFixtures.app(
        bundleIdentifier: "com.microsoft.VSCode", name: "Visual Studio Code", pid: 1004),
      TestFixtures.app(bundleIdentifier: "com.apple.Terminal", name: "Terminal", pid: 1005),
    ]
  }

  @Test("Exact match scores highest")
  func testExactMatch() async {
    // Arrange
    let search = FuzzySearchService()

    // Act
    let results = await search.search("Safari", in: testApps)

    // Assert
    #expect(results.first?.app.localizedName == "Safari", "Exact match should be first")
    #expect(results.first?.score == 1.0, "Exact match should score 1.0 (100%)")
  }

  @Test("Prefix match scores high")
  func testPrefixMatch() async {
    // Arrange
    let search = FuzzySearchService()

    // Act
    let results = await search.search("Sys", in: testApps)

    // Assert
    let systemSettings = results.first { $0.app.localizedName == "System Settings" }
    #expect(systemSettings != nil, "Should find System Settings")
    #expect((systemSettings?.score ?? 0) >= 0.8, "Prefix match should score >= 0.8")
  }

  @Test("Case insensitive matching")
  func testCaseInsensitive() async {
    // Arrange
    let search = FuzzySearchService()

    // Act
    let results1 = await search.search("safari", in: testApps)
    let results2 = await search.search("SAFARI", in: testApps)
    let results3 = await search.search("SaFaRi", in: testApps)

    // Assert
    #expect(results1.first?.app.localizedName == "Safari")
    #expect(results2.first?.app.localizedName == "Safari")
    #expect(results3.first?.app.localizedName == "Safari")

    // Scores should be identical for different cases
    #expect(results1.first?.score == results2.first?.score)
    #expect(results2.first?.score == results3.first?.score)
  }

  @Test("Fuzzy character matching")
  func testFuzzyMatching() async {
    // Arrange
    let search = FuzzySearchService()

    // Act
    let results = await search.search("vsc", in: testApps)

    // Assert
    let vscode = results.first { $0.app.localizedName.contains("Visual Studio Code") }
    #expect(vscode != nil, "Should match VSCode with 'vsc' query")

    // Also test other fuzzy patterns
    let chromeResults = await search.search("gc", in: testApps)
    let chrome = chromeResults.first { $0.app.localizedName == "Google Chrome" }
    #expect(chrome != nil, "Should match Google Chrome with 'gc'")
  }

  @Test("Empty query returns all apps")
  func testEmptyQuery() async {
    // Arrange
    let search = FuzzySearchService()

    // Act
    let results = await search.search("", in: testApps)

    // Assert
    #expect(results.count == testApps.count, "Empty query should return all apps")
    for result in results {
      #expect(result.score == 1.0, "Empty query gives all apps score 1.0")
    }
  }

  @Test("No matches returns empty array")
  func testNoMatches() async {
    // Arrange
    let search = FuzzySearchService()

    // Act
    let results = await search.search("qwx987", in: testApps)

    // Assert
    #expect(results.isEmpty, "Non-matching query should return empty array")
  }

  @Test("Match fields are correctly identified")
  func testMatchedFields() async {
    // Arrange
    let search = FuzzySearchService()

    // Act - search by app name
    let nameResults = await search.search("Chrome", in: testApps)

    // Assert
    if let chrome = nameResults.first(where: { $0.app.localizedName == "Google Chrome" }) {
      #expect(chrome.matchedFields.contains(.appName), "Should identify app name field match")
    }

    // Act - search by bundle ID part
    let bundleResults = await search.search("microsoft", in: testApps)

    // Assert
    if let vscode = bundleResults.first(where: { $0.app.bundleIdentifier.contains("microsoft") }) {
      #expect(vscode.matchedFields.contains(.bundleIdentifier), "Should identify bundle ID match")
    }
  }

  @Test("Performance: Search completes quickly")
  func testSearchPerformance() async {
    // Arrange
    let search = FuzzySearchService()
    var largeAppList: [AppInfo] = []
    for i in 0..<100 {
      largeAppList.append(
        AppInfo(
          bundleIdentifier: "com.test.app\(i)",
          localizedName: "Test Application Number \(i)",
          processIdentifier: pid_t(2000 + i),
          icon: NSImage()
        ))
    }

    // Act
    let startTime = Date()
    _ = await search.search("Test", in: largeAppList)
    let duration = Date().timeIntervalSince(startTime)

    // Assert
    #expect(
      duration < 0.05, "Search should complete within 50ms for 100 items (actual: \(duration)s)")
  }

  @Test("Bundle ID matching as fallback")
  func testBundleIDMatching() async {
    // Arrange
    let search = FuzzySearchService()

    // Act
    let results = await search.search("microsoft", in: testApps)

    // Assert
    let vscode = results.first { $0.app.bundleIdentifier.contains("microsoft") }
    #expect(vscode != nil, "Should match on bundle ID when name doesn't match")
    #expect(vscode?.app.localizedName == "Visual Studio Code")
  }

  @Test("Scoring differentiates match quality")
  func testScoringQuality() async {
    // Arrange
    let search = FuzzySearchService()
    let similarApps = [
      AppInfo(
        bundleIdentifier: "com.test.app1",
        localizedName: "Terminal",
        processIdentifier: 2001,
        icon: NSImage()
      ),
      AppInfo(
        bundleIdentifier: "com.test.app2",
        localizedName: "Terminal Pro",
        processIdentifier: 2002,
        icon: NSImage()
      ),
      AppInfo(
        bundleIdentifier: "com.test.app3",
        localizedName: "iTerm",
        processIdentifier: 2003,
        icon: NSImage()
      ),
    ]

    // Act
    let results = await search.search("Terminal", in: similarApps)

    // Assert
    #expect(results.count >= 2, "Should match multiple terminal apps")
    if results.count >= 2 {
      // Exact match should score higher than prefix match
      #expect(results[0].app.localizedName == "Terminal", "Exact match should be first")
      #expect(results[0].score > results[1].score, "Exact match should score higher")
    }
  }

  @Test("Handles special characters in queries")
  func testSpecialCharacters() async {
    // Arrange
    let search = FuzzySearchService()
    let specialApps = [
      AppInfo(
        bundleIdentifier: "com.test.app",
        localizedName: "App (Beta)",
        processIdentifier: 3001,
        icon: NSImage()
      ),
      AppInfo(
        bundleIdentifier: "com.test.plus",
        localizedName: "App+",
        processIdentifier: 3002,
        icon: NSImage()
      ),
    ]

    // Act
    let results1 = await search.search("App (Beta)", in: specialApps)
    let results2 = await search.search("App+", in: specialApps)

    // Assert
    #expect(results1.first?.app.localizedName == "App (Beta)", "Should handle parentheses")
    #expect(results2.first?.app.localizedName == "App+", "Should handle plus sign")
  }

  @Test("Search results are sorted by score")
  func testResultsSorted() async {
    // Arrange
    let search = FuzzySearchService()

    // Act
    let results = await search.search("S", in: testApps)

    // Assert
    if results.count > 1 {
      for i in 0..<(results.count - 1) {
        #expect(
          results[i].score >= results[i + 1].score,
          "Results should be sorted by score (descending)")
      }
    }
  }

  @Test("Service is Sendable compliant")
  func testSendableCompliance() async {
    // This test verifies compile-time Sendable compliance
    let search = FuzzySearchService()

    // Should compile without warnings in Swift 6.0+ strict concurrency
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        _ = await search.search("test", in: self.testApps)
      }
      group.addTask {
        _ = await search.search("another", in: self.testApps)
      }

      // Wait for tasks
      for await _ in group {}
    }

    // Sendable compliance verified
  }
}
