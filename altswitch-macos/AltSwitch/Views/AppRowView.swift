//
//  AppRowView.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import MacWindowDiscovery
import SwiftUI

struct AppRowView: View {
  let app: AppInfo
  let isSelected: Bool
  var searchResult: SearchResult?
  var showMatchHighlight: Bool = false
  var quickSelectIndex: Int?

  @State private var isHovered = false
  @AppStorage("debugMode") private var debugMode = false

  var body: some View {
    HStack(spacing: 12) {
      // App icon - 32x32
      Image(nsImage: app.icon)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 32, height: 32)
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)

      // App name and window count
      VStack(alignment: .leading, spacing: 2) {
        // App name with optional match highlighting
        if showMatchHighlight, let result = searchResult {
          highlightedText(for: result)
        } else {
          Text(app.localizedName)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Color.primary)
        }

        // Window title (if present, for individual window mode)
        if let windowTitle = app.windowTitle, !windowTitle.isEmpty {
          Text(windowTitle)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        // Debug info (window ID, process ID, cache status)
        if debugMode {
          let windowID = app.windows.first?.id ?? 0
          let isCached = MacWindowDiscovery.AXElementStore.shared.get(for: CGWindowID(windowID)) != nil
          let widStr = String(format: "%lu", windowID)
          let pidStr = String(format: "%d", app.processIdentifier)
          Text("WID:\(widStr) PID:\(pidStr) Cached:\(isCached ? "✓" : "✗")")
            .font(.system(size: 9, design: .monospaced))
            .foregroundStyle(.orange)
            .lineLimit(1)
        }

        // Window count and status
        HStack(spacing: 4) {
          if !app.windows.isEmpty && app.windowTitle == nil {
            HStack(spacing: 2) {
              Image(systemName: "macwindow")
                .font(.system(size: 10))
              Text("\(app.windows.count)")
                .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
          }
        }
      }

      Spacer()

      HStack(spacing: 8) {
        if shouldShowActiveIndicator {
          activeIndicator
        }

        // Quick select number for first 9 items
        if let quickSelectIndex = quickSelectIndex, quickSelectIndex < 9 {
          quickSelectBadge(number: quickSelectIndex + 1)
        }
        // Window count badge (only show if no quick select and multiple windows)
        else if app.windows.count > 1 {
          windowCountBadge
        }
      }
    }
    .frame(height: AltSwitchConstants.rowHeight)
    .padding(.horizontal, 8)
    .contentShape(Rectangle())
    .background(backgroundForState)
    .onHover { hovering in
      isHovered = hovering
    }
  }

  // MARK: - Active Indicator

  private var shouldShowActiveIndicator: Bool {
    if app.windowTitle != nil {
      guard app.isActive, let window = app.windows.first else { return false }
      return window.isFocused || window.isMainWindow
    }

    return app.isActive
  }

  private var activeIndicator: some View {
    Circle()
      .fill(Color.green.opacity(0.85))
      .frame(width: 8, height: 8)
  }

  // MARK: - Quick Select Badge

  @ViewBuilder
  private func quickSelectBadge(number: Int) -> some View {
    ZStack {
      Capsule()
        .fill(Color.accentColor.opacity(isSelected ? 0.4 : 0.25))
        .overlay(
          Capsule()
            .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 0.5)
        )

      Text("⌘\(number)")
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(Color.primary.opacity(0.8))
    }
    .frame(width: 32, height: 18)
  }

  // MARK: - Window Count Badge

  @ViewBuilder
  private var windowCountBadge: some View {
    ZStack {
      Capsule()
        .fill(Color.secondary.opacity(isSelected ? 0.3 : 0.15))

      Text("\(app.windows.count)")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
    }
    .frame(width: 24, height: 18)
  }

  // MARK: - Background

  @ViewBuilder
  private var backgroundForState: some View {
    if isSelected {
      RoundedRectangle(cornerRadius: 6)
        .fill(Color.accentColor.opacity(0.12))
    } else if isHovered {
      RoundedRectangle(cornerRadius: 6)
        .fill(Color.primary.opacity(0.05))
    } else {
      Color.clear
    }
  }

  // MARK: - Text Highlighting

  @ViewBuilder
  private func highlightedText(for result: SearchResult) -> some View {
    let text = app.localizedName

    // Simple highlight for matched fields
    if result.matchedFields.contains(.name) {
      Text(text)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color.primary)
        .underline(color: Color.accentColor.opacity(0.3))
    } else {
      Text(text)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(Color.primary)
    }
  }
}

// MARK: - Preview

#Preview("Single Row") {
  AppRowView(
    app: AppInfo.preview,
    isSelected: false
  )
  .padding()
  .frame(width: 600)
  .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Selected Row") {
  AppRowView(
    app: AppInfo.preview,
    isSelected: true
  )
  .padding()
  .frame(width: 600)
  .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Row List") {
  VStack(spacing: 2) {
    ForEach(Array(AppInfo.previewList.enumerated()), id: \.element.id) { index, app in
      AppRowView(
        app: app,
        isSelected: index == 1
      )
    }
  }
  .padding()
  .frame(width: 600)
  .background(Color(NSColor.windowBackgroundColor))
}
