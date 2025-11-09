//
//  SearchBar.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import Combine
import SwiftUI

/// Spotlight-style search bar with debounced input
struct SearchBar: View {
  @Binding var searchText: String
  let focus: FocusState<Bool>.Binding
  let onSearchChanged: (String) -> Void

  var body: some View {
    HStack(spacing: 12) {
      // Search icon
      Image(systemName: "magnifyingglass")
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 20)

      // Text field
      TextField("Search applications...", text: $searchText)
        .textFieldStyle(.plain)
        .font(.system(size: 16))
        .focused(focus)
        .onSubmit {
          // Immediate search on Enter
          performSearch()
        }
        .onChange(of: searchText) { _, newValue in
          onSearchChanged(newValue)
        }

      // Clear button
      if !searchText.isEmpty {
        Button(action: clearSearch) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 14))
            .foregroundStyle(.tertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Clear search")
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(searchBarBackground)
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
    )
  }

  // MARK: - Background

  private var searchBarBackground: some View {
    RoundedRectangle(cornerRadius: 16)
      .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .fill(focus.wrappedValue ? Color.accentColor.opacity(0.05) : Color.clear)
      )
  }

  // MARK: - Actions

  private func clearSearch() {
    searchText = ""
    onSearchChanged("")
    focus.wrappedValue = true
  }

  private func performSearch() {
    onSearchChanged(searchText)
  }
}

// MARK: - Keyboard Shortcuts

extension SearchBar {
  func onEscapeKey() -> some View {
    self.onKeyPress(keys: [.escape]) { _ in
      if !searchText.isEmpty {
        clearSearch()
        return .handled
      }
      return .ignored
    }
  }
}

// MARK: - Preview

#Preview("Empty") {
  SearchBarPreviewContainer(initialText: "")
}

#Preview("With Text") {
  SearchBarPreviewContainer(initialText: "Safari")
}

private struct SearchBarPreviewContainer: View {
  @State private var searchText: String
  @FocusState private var isFocused: Bool

  init(initialText: String) {
    _searchText = State(initialValue: initialText)
  }

  var body: some View {
    SearchBar(
      searchText: $searchText,
      focus: $isFocused,
      onSearchChanged: { text in
        print("Search: \(text)")
      }
    )
    .padding()
    .frame(width: 600)
    .frame(width: 600)
    .background(Color(NSColor.windowBackgroundColor))
    .onAppear {
      isFocused = true
    }
  }
}
