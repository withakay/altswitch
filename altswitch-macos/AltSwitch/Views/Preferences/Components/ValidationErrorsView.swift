//
//  ValidationErrorsView.swift
//  AltSwitch
//
//  Validation errors display
//

import SwiftUI

/// Validation errors display
struct ValidationErrorsView: View {
  let settingsViewModel: SettingsViewModel

  var body: some View {
    if !settingsViewModel.allValidationErrors.isEmpty {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
          Text("Configuration Issues")
            .font(.caption)
            .fontWeight(.semibold)
        }

        ForEach(settingsViewModel.allValidationErrors, id: \.self) { error in
          Text("• \(error)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding()
      .background(Color.orange.opacity(0.1))
      .cornerRadius(8)
    }
  }
}

#Preview("Validation Errors") {
  // Note: Preview requires proper dependency setup in actual app context
  Text("Validation Errors Preview")
    .padding()
}
