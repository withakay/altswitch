//
//  AdvancedTab.swift
//  AltSwitch
//
//  Advanced settings and diagnostic information
//

import SwiftUI

struct AdvancedTab: View {
  // MARK: - Environment & State
  @Environment(SettingsViewModel.self) private var settingsViewModel
  @Environment(MainViewModel.self) private var mainViewModel
  @State private var isExporting = false
  @State private var exportStatus: String?
  @State private var exportError: String?

  // MARK: - Body
  var body: some View {
    Form {
      Section("Status Messages") {
        StatusMessagesView(settingsViewModel: settingsViewModel)
      }

      Section("Validation & Diagnostics") {
        ValidationErrorsView(settingsViewModel: settingsViewModel)
      }

      Section("Debug Information") {
        VStack(alignment: .leading, spacing: 8) {
          LabeledContent("App Version") {
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
              .foregroundColor(.secondary)
          }

          LabeledContent("Build Number") {
            Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
              .foregroundColor(.secondary)
          }

          Divider()

          HStack {
            Image(systemName: "info.circle")
              .foregroundColor(.blue)
            Text(
              "Status messages and validation errors will appear above when actions are performed"
            )
            .font(.caption)
            .foregroundColor(.secondary)
          }
        }
      }

      Section("Window Discovery Debug") {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 12) {
            Button {
              exportWindowDebugInfo()
            } label: {
              HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("Export Window Debug Info")
              }
            }
            .disabled(isExporting)

            Button {
              openConfigFolder()
            } label: {
              HStack {
                Image(systemName: "folder")
                Text("Open Config Folder")
              }
            }

            if isExporting {
              ProgressView()
                .scaleEffect(0.7)
            }
          }

          if let status = exportStatus {
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
              Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }

          if let error = exportError {
            HStack {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
              Text(error)
                .font(.caption)
                .foregroundColor(.red)
            }
          }

          Divider()

          HStack {
            Image(systemName: "info.circle")
              .foregroundColor(.blue)
            Text(
              "Exports all window information to ~/.config/altswitch/debug/. Includes both visible and filtered windows with detailed metadata."
            )
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    .padding()
    .formStyle(.grouped)
  }

  // MARK: - Helper Methods

  private func exportWindowDebugInfo() {
    isExporting = true
    exportStatus = nil
    exportError = nil

    Task {
      do {
        let fileURL = try await mainViewModel.appDiscovery.dumpWindowDebugInfo()
        await MainActor.run {
          isExporting = false
          exportStatus = "Exported to \(fileURL.lastPathComponent)"
          // Clear status after 5 seconds
          Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            exportStatus = nil
          }
        }
      } catch {
        await MainActor.run {
          isExporting = false
          exportError = "Export failed: \(error.localizedDescription)"
          // Clear error after 5 seconds
          Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            exportError = nil
          }
        }
      }
    }
  }

  private func openConfigFolder() {
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    let configURL =
      homeURL
      .appendingPathComponent(".config")
      .appendingPathComponent("altswitch")

    // Create directory if it doesn't exist
    if !FileManager.default.fileExists(atPath: configURL.path) {
      try? FileManager.default.createDirectory(at: configURL, withIntermediateDirectories: true)
    }

    // Open in Finder
    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configURL.path)
  }
}

#Preview("Advanced Tab") {
  AdvancedPreviewContainer()
}

// Helper container for previews
private struct AdvancedPreviewContainer: View {
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

      AdvancedTab()
        .environment(mockSettingsVM)
        .environment(mockMainVM)
    } else {
      Text("Preview unavailable")
    }
  }
}
