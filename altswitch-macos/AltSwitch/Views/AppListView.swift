//
//  AppListView.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import AppKit
import SwiftUI

/// Scrollable list of app search results with keyboard navigation
struct AppListView: View {
  let searchResults: [SearchResult]
  @Binding var selectedIndex: Int
  let onSelect: (SearchResult) -> Void
  let maxHeight: CGFloat

  private static let rowSpacing: CGFloat = 2
  private static let topPadding: CGFloat = 8
  private static let bottomPadding: CGFloat = 0

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: Self.rowSpacing) {
          ForEach(Array(searchResults.enumerated()), id: \.element.app.id) { index, result in
            AppRowView(
              app: result.app,
              isSelected: index == selectedIndex,
              searchResult: result,
              showMatchHighlight: !result.matchedFields.isEmpty,
              quickSelectIndex: index < 9 ? index : nil
            )
            .id(index)
            .onTapGesture {
              selectedIndex = index
              onSelect(result)
            }
          }
        }
        .padding(.top, Self.topPadding)
        .padding(.bottom, Self.bottomPadding)
        .padding(.horizontal, 8)
        .drawingGroup()
      }
      .scrollIndicators(.never)
      .frame(maxHeight: maxHeight)
      .onChange(of: selectedIndex) { _, newIndex in
        // Instant scroll for super snappy navigation
        proxy.scrollTo(newIndex, anchor: .center)
      }
    }
  }
}

// MARK: - Layout Helpers

extension AppListView {
  static let layoutRowSpacing: CGFloat = rowSpacing
  static let layoutVerticalPadding: CGFloat = topPadding + bottomPadding  // top + bottom
}

// MARK: - Preview Helper

private struct PreviewContent: View {
  @State private var selectedIndex = 0

  let searchResults: [SearchResult] = {
    AppInfo.previewList.enumerated().map { index, app in
      SearchResult(
        app: app,
        score: Double(10 - index) / 10.0,
        matchedFields: index == 0 ? [.name] : []
      )
    }
  }()

  var body: some View {
    VStack {
      AppListView(
        searchResults: searchResults,
        selectedIndex: $selectedIndex,
        onSelect: { result in
          print("Selected: \(result.app.localizedName)")
        },
        maxHeight: 600
      )
    }
    .frame(width: 600)
    .background(Color(NSColor.windowBackgroundColor))
    .drawingGroup()
  }
}

// MARK: - Preview

#Preview("App List") {
  PreviewContent()
}

#Preview("Empty List") {
  VStack {
    AppListView(
      searchResults: [],
      selectedIndex: .constant(0),
      onSelect: { _ in },
      maxHeight: 600
    )
  }
  .frame(width: 600)
  .background(Color(NSColor.windowBackgroundColor))
}
