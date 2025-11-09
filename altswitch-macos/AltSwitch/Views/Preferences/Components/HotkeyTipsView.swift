//
//  HotkeyTipsView.swift
//  AltSwitch
//
//  Tips section for hotkey configuration
//

import SwiftUI

/// Tips section for hotkey configuration
struct HotkeyTipsView: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Tips:")
        .font(.caption)
        .fontWeight(.semibold)

      VStack(alignment: .leading, spacing: 4) {
        Text("• At least one modifier key (⌘, ⌥, ⇧, ⌃) is required")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("• Some combinations may conflict with system shortcuts")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("• Changes are saved automatically when you make them")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
}

#Preview("Hotkey Tips") {
  HotkeyTipsView()
    .padding()
}
