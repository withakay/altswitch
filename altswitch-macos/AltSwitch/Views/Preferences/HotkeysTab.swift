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
  private let doubleTapWindowMs = Int(ModifierDoubleTapDetector.defaultTapWindow * 1_000)
  private var activationOptions: [ActivationOption] {
    [
      ActivationOption(
        mode: .cmdTab,
        title: "Command + Tab",
        subtitle: "Replace the system switcher while held",
        icon: "command",
        accent: .blue,
        badge: "System override"
      ),
      ActivationOption(
        mode: .altTab,
        title: "Option + Tab",
        subtitle: "Keep Cmd+Tab intact; still cycle with Tab",
        icon: "option",
        accent: .orange,
        badge: "Classic"
      ),
      ActivationOption(
        mode: .doubleTapOption,
        title: "Double-tap Option (⌥⌥)",
        subtitle: "Tap ⌥ twice anywhere to pop open AltSwitch",
        icon: "bolt.circle",
        accent: .pink,
        badge: nil
      ),
      ActivationOption(
        mode: .doubleTapCommand,
        title: "Double-tap Command (⌘⌘)",
        subtitle: "No extra key needed—tap ⌘ twice",
        icon: "command.circle",
        accent: .purple,
        badge: nil
      ),
      ActivationOption(
        mode: .doubleTapControl,
        title: "Double-tap Control (⌃⌃)",
        subtitle: "Low-conflict gesture for terminal users",
        icon: "shield.lefthalf.filled",
        accent: .teal,
        badge: nil
      ),
      ActivationOption(
        mode: .doubleTapShift,
        title: "Double-tap Shift (⇧⇧)",
        subtitle: "Great for single-handed use",
        icon: "arrow.up.circle",
        accent: .indigo,
        badge: nil
      ),
      ActivationOption(
        mode: .custom,
        title: "Custom Shortcut",
        subtitle: "Pick any chord with full flexibility",
        icon: "keyboard",
        accent: .green,
        badge: nil
      ),
    ]
  }

  private let activationColumns = [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12),
  ]

  // MARK: - Body

  var body: some View {
    Form {
      Section("Activation") {
        VStack(alignment: .leading, spacing: 12) {
          Text("Pick how you want to open AltSwitch.")
            .font(.subheadline)
            .foregroundColor(.secondary)

          LazyVGrid(columns: activationColumns, spacing: 12) {
            ForEach(activationOptions) { option in
              ActivationCard(
                option: option,
                isSelected: hotkeyMode == option.mode
              ) {
                hotkeyMode = option.mode
              }
            }
          }

          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
              .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 4) {
              Text(hotkeyMode.description)
                .font(.caption)
                .foregroundColor(.secondary)

              if let doubleTap = hotkeyMode.doubleTapModifier {
                Text(
                  "\(doubleTap.symbol)\(doubleTap.symbol) taps within \(doubleTapWindowMs)ms toggle AltSwitch; any other key press resets the gesture."
                )
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
      }

      // Custom Hotkey Recorder (only show when using custom mode)
      if hotkeyMode == .custom {
        Section("Custom Hotkey") {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text("Custom hotkey")
              Text("Choose any chord to toggle AltSwitch")
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
    .onChange(of: hotkeyMode) { _, newMode in
      updateHotkeyMode(newMode)
    }
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

// MARK: - UI Components

private struct ActivationOption: Identifiable {
  let mode: HotkeyMode
  let title: String
  let subtitle: String
  let icon: String
  let accent: Color
  let badge: String?

  var id: String { mode.rawValue }
}

private struct ActivationCard: View {
  let option: ActivationOption
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .center) {
          Image(systemName: option.icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(option.accent)
            .frame(width: 20, height: 20)

          Spacer()

          if let badge = option.badge {
            Text(badge)
              .font(.caption2)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(option.accent.opacity(0.15))
              .foregroundColor(option.accent)
              .clipShape(Capsule())
          }

          if isSelected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.accentColor)
              .font(.system(size: 15, weight: .semibold))
          }
        }

        Text(option.title)
          .font(.headline)
          .foregroundColor(.primary)

        Text(option.subtitle)
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.03))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: isSelected ? 1.5 : 1)
      )
    }
    .buttonStyle(.plain)
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
