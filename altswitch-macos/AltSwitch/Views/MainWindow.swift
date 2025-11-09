//
//  MainWindow.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import AppKit
import SwiftUI

/// Main floating window with Spotlight-style interface
struct MainWindow: View {
  @Environment(MainViewModel.self) var viewModel
  @FocusState private var isSearchFocused: Bool

  // MARK: - Layout (FR-005, FR-006: Simplified to use SwiftUI's native layout)

  private var screenHeight: CGFloat {
    let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" })
    return window?.screen?.frame.height ?? NSScreen.main?.frame.height ?? 900
  }

  private var desiredWindowHeight: CGFloat {
    let rows = max(viewModel.filteredApps.count, 1)
    let rowHeight = AltSwitchConstants.rowHeight
    let rowSpacing = AppListView.layoutRowSpacing
    let listVerticalPadding = AppListView.layoutVerticalPadding
    let searchAreaHeight = AltSwitchConstants.searchContainerHeight
    let dividerThickness: CGFloat = 1  // SwiftUI Divider is just a hairline

    let contentHeight =
      (CGFloat(rows) * rowHeight)
      + (CGFloat(rows - 1) * rowSpacing)
      + listVerticalPadding
    let desiredHeight = contentHeight + searchAreaHeight + dividerThickness
    let maxHeight = screenHeight * AltSwitchConstants.windowMaxHeightRatio
    let availableHeight = screenHeight * (1 - (AltSwitchConstants.windowVerticalMarginRatio * 2))
    let finalHeight = min(desiredHeight, maxHeight, availableHeight)

    return finalHeight
  }

  // MARK: - AppSwitcherContent Component (FR-001)

  private struct AppSwitcherContent: View {
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let filteredApps: [SearchResult]
    @Binding var selectedIndex: Int
    let listMaxHeight: CGFloat
    let onSelect: (SearchResult) -> Void

    var body: some View {
      VStack(spacing: 0) {
        SearchBar(
          searchText: $searchText,
          focus: $isSearchFocused,
          onSearchChanged: { searchText = $0 }
        )
        .padding(16)

        Divider()
          .opacity(0.3)

        contentArea
      }
    }

    @ViewBuilder
    private var contentArea: some View {
      if !searchText.isEmpty && filteredApps.isEmpty {
        emptyState
      } else {
        AppListView(
          searchResults: filteredApps,
          selectedIndex: $selectedIndex,
          onSelect: onSelect,
          maxHeight: listMaxHeight
        )
      }
    }

    private var emptyState: some View {
      VStack(spacing: 12) {
        Image(systemName: "magnifyingglass")
          .font(.system(size: 48))
          .foregroundStyle(.tertiary)
        Text("No apps found")
          .font(.headline)
          .foregroundStyle(.secondary)
        Text("Try a different search term")
          .font(.subheadline)
          .foregroundStyle(.tertiary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding()
    }
  }

  var body: some View {
    mainContent
      .frame(width: 600, height: desiredWindowHeight)
  }

  @ViewBuilder
  private var mainContent: some View {
    AppSwitcherContent(
      searchText: Binding(
        get: { viewModel.searchText },
        set: { viewModel.searchText = $0 }
      ),
      isSearchFocused: $isSearchFocused,
      filteredApps: viewModel.filteredApps,
      selectedIndex: Binding(
        get: { viewModel.selectedIndex },
        set: { viewModel.selectedIndex = $0 }
      ),
      listMaxHeight: screenHeight * AltSwitchConstants.windowMaxHeightRatio,
      onSelect: selectApp
    )
    .onAppear {
      print("👁️ [MainWindow.onAppear] START - filteredApps.count: \(viewModel.filteredApps.count)")
      setupWindow()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        isSearchFocused = true
      }
      Task {
        print("🔄 [MainWindow.onAppear] Calling refreshApps()")
        await viewModel.refreshApps()
        print("✅ [MainWindow.onAppear] refreshApps() complete - filteredApps.count: \(viewModel.filteredApps.count)")
      }
    }
    .onChange(of: viewModel.isVisible) { _, isVisible in
      print("🔔 [MainWindow.onChange(isVisible)] isVisible changed to: \(isVisible)")
      if isVisible {
        // Note: refreshApps() is already called in show() before isVisible=true
        // No need to call it again here
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
          isSearchFocused = true
        }
      }
    }
    .onExitCommand {
      viewModel.hide()
    }
    .onKeyPress(keys: [.upArrow]) { _ in
      viewModel.selectPrevious()
      return .handled
    }
    .onKeyPress(keys: [.downArrow]) { _ in
      viewModel.selectNext()
      return .handled
    }
    .onKeyPress(keys: [.return]) { _ in
      Task {
        await viewModel.switchToSelectedApp()
      }
      return .handled
    }
    .onKeyPress { keyPress in
      guard keyPress.key == .tab else { return .ignored }
      if keyPress.modifiers.contains(.shift) {
        viewModel.cycleBackward()
      } else {
        viewModel.cycleForward()
      }
      isSearchFocused = true
      return .handled
    }
  }

  // MARK: - Helper Methods

  private func setupWindow() {
    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
      window.makeKeyAndOrderFront(nil)
    }
  }

  private func selectApp(_ result: SearchResult) {
    if let index = viewModel.filteredApps.firstIndex(where: {
      $0.app.bundleIdentifier == result.app.bundleIdentifier
    }) {
      viewModel.selectedIndex = index
      isSearchFocused = true
      Task {
        await viewModel.switchToSelectedApp()
      }
    }
  }
}

// MARK: - Preview

#Preview("Light Mode") {
  MainWindow()
    .environment(MainViewModel())
    .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
  MainWindow()
    .environment(MainViewModel())
    .preferredColorScheme(.dark)
}
