//
//  SearchResult.swift
//  AltSwitch
//
//  Fuzzy search result with scoring
//

import Foundation

struct SearchResult {
  let app: AppInfo
  let score: Double
  let matchedFields: Set<MatchField>
  let highlightRanges: [NSRange]

  enum MatchField {
    case appName
    case name  // Alias for appName to maintain compatibility
    case bundleIdentifier
    case windowTitle
  }

  init(
    app: AppInfo,
    score: Double,
    matchedFields: Set<MatchField>,
    highlightRanges: [NSRange] = []
  ) {
    precondition(score >= 0.0 && score <= 1.0, "Score must be in range 0.0-1.0")
    // Allow empty matched fields when generating results without fuzzy data

    self.app = app
    self.score = score
    self.matchedFields = matchedFields
    self.highlightRanges = highlightRanges
  }
}

// MARK: - Identifiable
extension SearchResult: Identifiable {
  var id: String { app.id }
}

// MARK: - Comparable (for sorting by score)
extension SearchResult: Comparable {
  static func < (lhs: SearchResult, rhs: SearchResult) -> Bool {
    // Higher scores should come first (descending order)
    lhs.score > rhs.score
  }
}

// MARK: - Equatable
extension SearchResult: Equatable {
  static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
    lhs.app == rhs.app && lhs.score == rhs.score
  }
}

// MARK: - Sendable Conformance
extension SearchResult: @unchecked Sendable {}

// MARK: - Legacy Support
extension SearchResult {
  /// Legacy MatchedField type for backward compatibility
  typealias MatchedField = MatchField
}
