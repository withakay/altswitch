//
//  PreferencesView.swift
//  AltSwitch
//
//  Refactored preferences interface following Browserino architecture
//

import SwiftUI

struct PreferencesView: View {
  var body: some View {
    TabView {
      GeneralTab()
        .tabItem {
          Label("General", systemImage: "gear")
        }
        .tag(0)

      PermissionsTab()
        .tabItem {
          Label("Permissions", systemImage: "lock.shield")
        }
        .tag(1)

      HotkeysTab()
        .tabItem {
          Label("Hotkeys", systemImage: "keyboard")
        }
        .tag(2)

      AppearanceTab()
        .tabItem {
          Label("Appearance", systemImage: "paintbrush")
        }
        .tag(3)

      FiltersTab()
        .tabItem {
          Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
        }
        .tag(4)

      AdvancedTab()
        .tabItem {
          Label("Advanced", systemImage: "gearshape.2")
        }
        .tag(5)
    }
    .frame(width: 600, height: 400)
  }
}

#Preview {
  PreferencesPreviewContainer()
}

// Helper container for previews
private struct PreferencesPreviewContainer: View {
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

      PreferencesView()
        .environment(mockSettingsVM)
        .environment(mockMainVM)
    } else {
      Text("Preview unavailable")
    }
  }
}
