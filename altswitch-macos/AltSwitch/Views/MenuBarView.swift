//
//  MenuBarView.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import SwiftUI

struct MenuBarView: View {
  @Environment(MainViewModel.self) private var viewModel
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Button("Show AltSwitch") {
        viewModel.show()
      }
      .keyboardShortcut(" ", modifiers: .command)

      Divider()
        .padding(.vertical, 4)

      Button("Settings...") {
        openSettings()
      }
      .keyboardShortcut(",", modifiers: .command)

      Divider()
        .padding(.vertical, 4)

      Button("About AltSwitch") {
        NSApp.orderFrontStandardAboutPanel(nil)
      }

      Button("Quit") {
        NSApp.terminate(nil)
      }
      .keyboardShortcut("q", modifiers: .command)
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  MenuBarView()
    .environment(MainViewModel())
}
