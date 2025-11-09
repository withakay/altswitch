//
//  FuzzySearchService.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import Foundation
import MacWindowDiscovery

/// Service for performing fuzzy search on applications
struct FuzzySearchService: FuzzySearchProtocol, Sendable {

  /// Perform a fuzzy search on the given items
  func search(_ query: String, in items: [AppInfo]) async -> [SearchResult] {
    // Empty query returns all items with score 1.0
    if query.isEmpty {
      return items.map {
        SearchResult(app: $0, score: 1.0, matchedFields: [.name])
      }
    }

    var results: [SearchResult] = []
    let lowercasedQuery = query.lowercased()

    for app in items {
      var bestScore: Double = 0
      var matchedFields: Set<SearchResult.MatchedField> = []

      // Check name matching
      let nameScore = calculateScore(query: lowercasedQuery, text: app.localizedName.lowercased())
      if nameScore > 0 {
        bestScore = max(bestScore, nameScore)
        matchedFields.insert(.name)
      }

      // Check bundle identifier matching
      let bundleScore = calculateScore(
        query: lowercasedQuery, text: app.bundleIdentifier.lowercased())
      if bundleScore > 0 {
        // Bundle ID matches are slightly penalized compared to name matches
        let adjustedBundleScore = bundleScore * 0.9
        if adjustedBundleScore > bestScore {
          bestScore = adjustedBundleScore
          matchedFields = [.bundleIdentifier]
        } else if bundleScore > 0 {
          matchedFields.insert(.bundleIdentifier)
        }
      }

      // Check window titles
      for window in app.windows {
        let windowScore = calculateScore(query: lowercasedQuery, text: window.title.lowercased())
        if windowScore > 0 {
          // Window title matches are further penalized
          let adjustedWindowScore = windowScore * 0.8
          if adjustedWindowScore > bestScore {
            bestScore = adjustedWindowScore
            matchedFields = [.windowTitle]
          } else if windowScore > 0 {
            matchedFields.insert(.windowTitle)
          }
        }
      }

      // Add to results if there's a match
      if bestScore > 0 {
        results.append(SearchResult(app: app, score: bestScore, matchedFields: matchedFields))
      }
    }

    // Sort by score (highest first)
    return results.sorted()
  }

  /// Calculate match score between query and text
  private func calculateScore(query: String, text: String) -> Double {
    // Exact match
    if text == query {
      return 1.0
    }

    // Prefix match
    if text.hasPrefix(query) {
      // Shorter texts with prefix match score higher
      let lengthRatio = Double(query.count) / Double(text.count)
      return 0.8 + (0.1 * lengthRatio)
    }

    // Word boundary match (e.g., "vs" matches "Visual Studio")
    let words = text.split(separator: " ")
    for word in words {
      if word.lowercased().hasPrefix(query) {
        return 0.6
      }
    }

    // Check for initials match (e.g., "vsc" matches "Visual Studio Code")
    if matchesInitials(query: query, text: text) {
      return 0.5
    }

    // Contains match
    if text.contains(query) {
      // Score based on position - earlier matches score higher
      if let range = text.range(of: query) {
        let position = text.distance(from: text.startIndex, to: range.lowerBound)
        let positionRatio = 1.0 - (Double(position) / Double(text.count))
        return 0.4 * positionRatio
      }
      return 0.4
    }

    // Fuzzy character matching - only for short queries
    if query.count <= 4 && fuzzyMatch(query: query, text: text) {
      return 0.2
    }

    return 0.0
  }

  /// Check if query matches the initials of the text
  private func matchesInitials(query: String, text: String) -> Bool {
    let words = text.split(separator: " ")
    let initials = words.compactMap { $0.first?.lowercased() }.joined()
    return initials.contains(query) || query.contains(initials)
  }

  /// Perform fuzzy character matching
  private func fuzzyMatch(query: String, text: String) -> Bool {
    // Don't do fuzzy matching if query is too long relative to text
    if query.count > text.count {
      return false
    }

    // Require a reasonable ratio of matched characters
    var queryIndex = query.startIndex
    var textIndex = text.startIndex
    var matchedCount = 0

    while queryIndex < query.endIndex && textIndex < text.endIndex {
      if query[queryIndex] == text[textIndex] {
        queryIndex = query.index(after: queryIndex)
        matchedCount += 1
      }
      textIndex = text.index(after: textIndex)
    }

    // All query characters were found in order
    // But also require that we matched at least most of the query
    return queryIndex == query.endIndex && matchedCount >= max(1, query.count * 2 / 3)
  }
}
