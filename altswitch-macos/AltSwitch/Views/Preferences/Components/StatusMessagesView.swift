//
//  StatusMessagesView.swift
//  AltSwitch
//
//  Status messages display
//

import SwiftUI

/// Status messages display
struct StatusMessagesView: View {
  let settingsViewModel: SettingsViewModel

  var body: some View {
    VStack(spacing: 8) {
      if let successMessage = settingsViewModel.successMessage {
        HStack {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
          Text(successMessage)
            .font(.caption)
        }
        .transition(.opacity)
      }

      if let errorMessage = settingsViewModel.errorMessage {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.red)
          Text(errorMessage)
            .font(.caption)
        }
        .transition(.opacity)
      }
    }
    .animation(.easeInOut, value: settingsViewModel.successMessage)
    .animation(.easeInOut, value: settingsViewModel.errorMessage)
  }
}

#Preview("Status Messages") {
  // Note: Preview requires proper dependency setup in actual app context
  Text("Status Messages Preview")
    .padding()
}
