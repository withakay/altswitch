//
//  GeneralTab.swift
//  AltSwitch
//
//  General settings and system integration preferences
//

import SwiftUI

struct GeneralTab: View {
  // MARK: - Environment & State
  @Environment(SettingsViewModel.self) private var settingsViewModel
  @Environment(MainViewModel.self) private var mainViewModel
  @AppStorage("launchAtLogin") private var launchAtLogin = false
  @AppStorage("showInDock") private var showInDock = false
  @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
  @AppStorage("debugMode") private var debugMode = false
  @State private var restrictToMainDisplay = false
  @State private var showIndividualWindows = true
  @State private var enableAnimations = true

  // MARK: - Body
  var body: some View {
    Form {
      Section("System Integration") {
        Toggle("Launch at login", isOn: $launchAtLogin)

        Toggle("Show in Dock", isOn: $showInDock)

        Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
      }

      Section("Window Behavior") {
        VStack(alignment: .leading, spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            Toggle("Show individual windows", isOn: $showIndividualWindows)

            Text("Show each window separately (e.g., all Finder windows listed individually)")
              .font(.caption)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Divider()

          VStack(alignment: .leading, spacing: 4) {
            Toggle("Restrict to main display", isOn: $restrictToMainDisplay)

            Text("When enabled, AltSwitch will always open on the main display")
              .font(.caption)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }

          Divider()

          VStack(alignment: .leading, spacing: 4) {
            Toggle("Enable animations", isOn: $enableAnimations)

            Text("Disable to make the window appear immediately without the show animation")
              .font(.caption)
              .foregroundColor(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }

      Section("Developer") {
        VStack(alignment: .leading, spacing: 4) {
          Toggle("Show debug information", isOn: $debugMode)

          Text("Display window IDs, process IDs, and cache status in the app list")
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding()
    .formStyle(.grouped)
    .onChange(of: showInDock) { _, newValue in
      NSApp.setActivationPolicy(newValue ? .regular : .accessory)
    }
    .onChange(of: showIndividualWindows) { _, newValue in
      applyWindowBehaviorChanges(showIndividualWindows: newValue)
    }
    .onChange(of: restrictToMainDisplay) { _, newValue in
      applyWindowBehaviorChanges(restrictToMainDisplay: newValue)
    }
    .onChange(of: enableAnimations) { _, newValue in
      applyWindowBehaviorChanges(enableAnimations: newValue)
    }
    .onAppear {
      restrictToMainDisplay = mainViewModel.configuration.restrictToMainDisplay
      showIndividualWindows = mainViewModel.configuration.showIndividualWindows
      enableAnimations = mainViewModel.configuration.enableAnimations
    }
  }
}

#Preview("General Tab") {
  PreviewContainer()
}

// MARK: - Helpers

private extension GeneralTab {
  func applyWindowBehaviorChanges(
    showIndividualWindows: Bool? = nil,
    restrictToMainDisplay: Bool? = nil,
    enableAnimations: Bool? = nil
  ) {
    Task { @MainActor in
      var newBehavior = mainViewModel.configuration.behaviorConfiguration
      newBehavior = BehaviorConfiguration(
        enableFuzzySearch: newBehavior.enableFuzzySearch,
        showWindowCounts: newBehavior.showWindowCounts,
        enableSounds: newBehavior.enableSounds,
        enableAnimations: enableAnimations ?? self.enableAnimations,
        restrictToMainDisplay: restrictToMainDisplay ?? self.restrictToMainDisplay,
        showIndividualWindows: showIndividualWindows ?? self.showIndividualWindows
      )
      try? await mainViewModel.updateBehavior(newBehavior)
    }
  }
}

// Helper container for previews
private struct PreviewContainer: View {
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

      GeneralTab()
        .environment(mockSettingsVM)
        .environment(mockMainVM)
    } else {
      Text("Preview unavailable")
    }
  }
}
