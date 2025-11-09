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
      Task {
        var newBehavior = mainViewModel.configuration.behaviorConfiguration
        newBehavior = BehaviorConfiguration(
          enableFuzzySearch: newBehavior.enableFuzzySearch,
          showWindowCounts: newBehavior.showWindowCounts,
          enableSounds: newBehavior.enableSounds,
          enableAnimations: newBehavior.enableAnimations,
          restrictToMainDisplay: newBehavior.restrictToMainDisplay,
          showIndividualWindows: newValue
        )
        try? await mainViewModel.updateBehavior(newBehavior)
      }
    }
    .onChange(of: restrictToMainDisplay) { _, newValue in
      Task {
        var newBehavior = mainViewModel.configuration.behaviorConfiguration
        newBehavior = BehaviorConfiguration(
          enableFuzzySearch: newBehavior.enableFuzzySearch,
          showWindowCounts: newBehavior.showWindowCounts,
          enableSounds: newBehavior.enableSounds,
          enableAnimations: newBehavior.enableAnimations,
          restrictToMainDisplay: newValue,
          showIndividualWindows: newBehavior.showIndividualWindows
        )
        try? await mainViewModel.updateBehavior(newBehavior)
      }
    }
    .onAppear {
      restrictToMainDisplay = mainViewModel.configuration.restrictToMainDisplay
      showIndividualWindows = mainViewModel.configuration.showIndividualWindows
    }
  }
}

#Preview("General Tab") {
  PreviewContainer()
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
