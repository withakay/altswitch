//
//  HotkeysTab.swift
//  AltSwitch
//
//  Keyboard shortcut configuration
//

import KeyboardShortcuts
import SwiftUI

struct HotkeysTab: View {
  // MARK: - Environment & State

  @Environment(SettingsViewModel.self) var settingsViewModel
  @Environment(MainViewModel.self) var mainViewModel
  @State private var overrideState = HotkeyOverrideState()
  @State private var hotkeyMode: HotkeyMode = .custom
  @State private var enableCycling: Bool = true

  // MARK: - Body

  var body: some View {
    Form {
      // Hotkey Mode Selection
      Section("Hotkey Mode") {
        Picker("Select a Hotkey combination", selection: $hotkeyMode) {
          ForEach(HotkeyMode.allCases) { mode in
            Text(mode.displayName).tag(mode)
          }
        }
        .pickerStyle(.segmented)
        .onChange(of: hotkeyMode) { _, newMode in
          updateHotkeyMode(newMode)
        }

        // Description for current mode
        HStack {
          Image(systemName: "info.circle")
            .foregroundColor(.blue)
          Text(hotkeyMode.description)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      // Custom Hotkey Recorder (only show when using custom mode)
      if hotkeyMode == .custom {
        Section("Custom Hotkey") {
          HStack {
            VStack(alignment: .leading, spacing: 0) {
              Text("Custom Hotkey:")
              Text("Global hotkey to toggle the app switcher")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            KeyboardShortcuts.Recorder(for: .showHideAltSwitch)
              .fixedSize()
          }
        }
        Section {
          HotkeyTipsView()
        }
      }

      // Cycling Behavior Settings (only show for Alt+Tab and Cmd+Tab modes)
      if hotkeyMode == .altTab || hotkeyMode == .cmdTab {
        Section("Cycling Behavior") {
          Toggle("Enable hold-and-cycle behavior", isOn: $enableCycling)
            .onChange(of: enableCycling) { _, newValue in
              saveCyclingSetting(newValue)
            }

          if enableCycling {
            HStack {
              Image(systemName: "info.circle")
                .foregroundColor(.blue)
              Text("Hold the modifier key and press Tab repeatedly to cycle through apps")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          } else {
            HStack {
              Image(systemName: "info.circle")
                .foregroundColor(.blue)
              Text("Press \(hotkeyMode.displayName) once to show AltSwitch for typing searches")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
        }
      }
    }
    .padding()
    .formStyle(.grouped)
    .onAppear {
      loadInitialState()
    }
  }

  // MARK: - Helper Functions

  private func loadInitialState() {
    hotkeyMode = overrideState.mode
    loadCyclingSettings()
    UserDefaults.standard.removeObject(forKey: "RequireSinglePress")
    applyHotkeyModeSettings(mode: hotkeyMode, notify: false)
  }

  private func updateHotkeyMode(_ mode: HotkeyMode) {
    applyHotkeyModeSettings(mode: mode, notify: true)
  }

  private func saveCyclingSetting(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: "EnableCycling")
  }

  private func loadCyclingSettings() {
    // Default to enabled if no setting exists
    enableCycling = UserDefaults.standard.object(forKey: "EnableCycling") as? Bool ?? true
  }

  private func applyHotkeyModeSettings(mode: HotkeyMode, notify: Bool) {
    overrideState.mode = mode
    overrideState.isAltTabEnabled = (mode == .altTab)
    overrideState.isCmdTabEnabled = (mode == .cmdTab)

    if mode == .custom {
      KeyboardShortcuts.enable(.showHideAltSwitch)
    } else {
      KeyboardShortcuts.disable(.showHideAltSwitch)
    }

    if notify {
      HotkeyCenter.shared.overrideModeDidChange(to: mode)
    }
  }
}

#Preview("Hotkeys Tab") {
  HotkeysPreviewContainer()
}

// Helper container for previews
private struct HotkeysPreviewContainer: View {
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

      HotkeysTab()
        .environment(mockSettingsVM)
        .environment(mockMainVM)
    } else {
      Text("Preview unavailable")
    }
  }
}
