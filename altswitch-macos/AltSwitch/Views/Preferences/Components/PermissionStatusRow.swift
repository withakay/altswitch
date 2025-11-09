//
//  PermissionStatusRow.swift
//  AltSwitch
//
//  Permission status row showing current permission state
//

import SwiftUI

/// Permission status row showing current permission state
struct PermissionStatusRow: View {
  let title: String
  let description: String
  let isGranted: Bool
  let permissionState: PermissionState

  var body: some View {
    HStack(spacing: 12) {
      // Status icon
      statusIcon
        .font(.title2)
        .frame(width: 32)

      // Permission info
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.body)
          .fontWeight(.medium)

        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)

        // State description
        Text(stateDescription)
          .font(.caption)
          .foregroundColor(stateColor)
      }

      Spacer()
    }
    .padding(.vertical, 4)
  }

  private var statusIcon: some View {
    Group {
      switch permissionState {
      case .granted:
        Image(systemName: "checkmark.circle.fill")
          .foregroundColor(.green)
      case .denied, .unknown:
        Image(systemName: "xmark.circle.fill")
          .foregroundColor(.red)
      case .checking:
        ProgressView()
          .scaleEffect(0.8)
      case .promptShown:
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundColor(.orange)
      }
    }
  }

  private var stateDescription: String {
    switch permissionState {
    case .granted:
      return "✓ Granted"
    case .denied:
      return "✗ Not granted"
    case .unknown:
      return "⚠ Unknown - Click \"Request Permission\" to check"
    case .checking:
      return "⏳ Checking..."
    case .promptShown:
      return "⚠ Waiting for user response"
    }
  }

  private var stateColor: Color {
    switch permissionState {
    case .granted:
      return .green
    case .denied:
      return .red
    case .unknown, .promptShown:
      return .orange
    case .checking:
      return .secondary
    }
  }
}

#Preview("Permission Status Row") {
  VStack(spacing: 8) {
    PermissionStatusRow(
      title: "Accessibility",
      description: "Required for app switching and keyboard shortcuts",
      isGranted: true,
      permissionState: .granted
    )

    PermissionStatusRow(
      title: "Accessibility",
      description: "Required for app switching and keyboard shortcuts",
      isGranted: false,
      permissionState: .denied
    )
  }
  .padding()
}
