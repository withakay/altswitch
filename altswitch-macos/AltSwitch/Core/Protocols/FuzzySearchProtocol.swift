//
//  FuzzySearchProtocol.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import Foundation

/// Protocol for performing fuzzy search on applications
protocol FuzzySearchProtocol: Sendable {
  /// Perform a fuzzy search on the given items
  /// - Parameters:
  ///   - query: The search query string
  ///   - items: The array of AppInfo items to search through
  /// - Returns: Array of SearchResult sorted by relevance (highest score first)
  func search(_ query: String, in items: [AppInfo]) async -> [SearchResult]
}
