//
//  PermissionsTab.swift
//  AltSwitch
//
//  Accessibility and system permissions management
//

import SwiftUI

struct PermissionsTab: View {
  // MARK: - Environment & State
  @Environment(SettingsViewModel.self) private var settingsViewModel
  @Environment(MainViewModel.self) private var mainViewModel
  @State private var permissionManager = AccessibilityPermissionManager.shared

  // MARK: - Body
  var body: some View {
    Form {
      Section("Accessibility Permission") {
        PermissionStatusRow(
          title: "Accessibility",
          description: "Required for app switching and keyboard shortcuts",
          isGranted: permissionManager.isGranted,
          permissionState: permissionManager.state
        )

        HStack {
          Button {
            permissionManager.openSystemSettings()
          } label: {
            Label("Open System Settings", systemImage: "gear")
          }
          .help("Open System Settings to grant permissions manually")

          Button {
            _ = permissionManager.requestPermissionIfNeeded()
          } label: {
            Label("Request Permission", systemImage: "lock.shield")
          }
          .help("Show system permission prompt")
          .disabled(permissionManager.isGranted)
        }
      }

      Section("Why Permissions Are Needed") {
        VStack(alignment: .leading, spacing: 12) {
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "keyboard")
              .foregroundColor(.blue)
              .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
              Text("Global Hotkeys")
                .font(.headline)
              Text("Capture keyboard shortcuts like Alt+Tab or Cmd+Tab system-wide")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
              .foregroundColor(.blue)
              .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
              Text("App Switching")
                .font(.headline)
              Text("Activate and bring applications to the foreground")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "macwindow")
              .foregroundColor(.blue)
              .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
              Text("Window Information")
                .font(.headline)
              Text("Read window titles and app information for search")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
    }
    .padding()
    .formStyle(.grouped)
  }
}

#Preview("Permissions Tab") {
  PermissionsPreviewContainer()
}

// Helper container for previews
private struct PermissionsPreviewContainer: View {
  var body: some View {
    if let mockSettings = try? SettingsManager() {
      let mockSettingsVM = SettingsViewModel.create(
        with: mockSettings,
        hotkeyManager: KeyboardShortcutsHotkeyManager()
      )
      let mockMainVM = MainViewModel(
        appDiscovery: PackageAppDiscovery(),
        appSwitcher: AppSwitcher.shared,
        fuzzySearch: FuzzySearchService(),
        hotkeyManager: KeyboardShortcutsHotkeyManager(),
        settingsManager: mockSettings
      )

      PermissionsTab()
        .environment(mockSettingsVM)
        .environment(mockMainVM)
    } else {
      Text("Preview unavailable")
    }
  }
}
