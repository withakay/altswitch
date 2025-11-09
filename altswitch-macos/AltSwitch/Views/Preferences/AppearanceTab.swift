//
//  AppearanceTab.swift
//  AltSwitch
//
//  Visual appearance and display preferences
//

import SwiftUI

struct AppearanceTab: View {
  @Environment(SettingsViewModel.self) private var settingsViewModel
  @AppStorage("windowTheme") private var windowTheme = "auto"
  @AppStorage("showWindowCount") private var showWindowCount = true
  @AppStorage("iconSize") private var iconSize = 32.0
  @State private var hotkeyInitDelay: Double = 0.1
  @State private var previousHotkeyInitDelay: Double = 0.1
  @State private var hasInitialized = false
  @State private var showError = false
  @State private var errorMessage = ""

  var body: some View {
    Form {
        
        /*
      Section("Theme") {
        Picker("Theme:", selection: $windowTheme) {
          Text("Auto").tag("auto")
          Text("Light").tag("light")
          Text("Dark").tag("dark")
        }
        .pickerStyle(.segmented)
      }
         */

      Section("Display Options") {
        // Toggle("Show window count", isOn: $showWindowCount)

        HStack {
          Text("Icon size:")
          Slider(value: $iconSize, in: 24...48, step: 4)
          Text("\(Int(iconSize))px")
            .monospacedDigit()
        }

        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text("Hotkey initialization delay:")
            Spacer()
            Text("\(Int(hotkeyInitDelay * 1000))ms")
              .monospacedDigit()
              .foregroundColor(.secondary)
          }

          Slider(value: $hotkeyInitDelay, in: 0...0.1, step: 0.01)
            .onChange(of: hotkeyInitDelay) { newValue in
              guard hasInitialized else { return }
              let clampedValue = min(max(newValue, 0), 0.1)

              if abs(clampedValue - previousHotkeyInitDelay) <= .ulpOfOne {
                return
              }

              Task { @MainActor in
                do {
                  try await settingsViewModel.applyHotkeyInitDelay(clampedValue)
                  previousHotkeyInitDelay = clampedValue
                  hotkeyInitDelay = clampedValue
                } catch {
                  hotkeyInitDelay = previousHotkeyInitDelay
                  errorMessage = "Failed to update hotkey delay: \(error.localizedDescription)"
                  showError = true
                }
              }
            }

          Text("Delay before hotkeys become active after app launch (0-100ms)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding()
    .formStyle(.grouped)
    .onAppear {
      let currentDelay = settingsViewModel.hotkeyInitDelay
      hotkeyInitDelay = currentDelay
      previousHotkeyInitDelay = currentDelay
      hasInitialized = true
    }
    .onChange(of: settingsViewModel.hotkeyInitDelay) { newValue in
      guard hasInitialized else { return }
      if abs(newValue - hotkeyInitDelay) > .ulpOfOne {
        hotkeyInitDelay = newValue
        previousHotkeyInitDelay = newValue
      }
    }
    .alert("Update Failed", isPresented: $showError) {
      Button("OK", role: .cancel) {
        showError = false
      }
    } message: {
      Text(errorMessage.isEmpty ? "Unable to update hotkey delay." : errorMessage)
    }
  }
}

#Preview("Appearance Tab") {
  AppearancePreviewContainer()
}

private struct AppearancePreviewContainer: View {
  var body: some View {
    if let mockSettings = try? SettingsManager() {
      let mockSettingsVM = SettingsViewModel.create(
        with: mockSettings,
        hotkeyManager: KeyboardShortcutsHotkeyManager()
      )

      AppearanceTab()
        .environment(mockSettingsVM)
    } else {
      Text("Preview unavailable")
    }
  }
}
