import AppKit
import Foundation

@MainActor
extension MainViewModel {
  func openSettings() {
    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func setupConfigurationObserver() {
    settingsManager.onConfigurationChanged { [weak self] newConfig in
      Task { @MainActor [weak self] in
        guard let self = self else { return }
        self.configuration = newConfig
        
        // Update PackageAppDiscovery filters
        if let packageDiscovery = self.appDiscovery as? PackageAppDiscovery {
          packageDiscovery.applicationNameExcludeList = newConfig.applicationNameExcludeList
          packageDiscovery.untitledWindowExcludeList = newConfig.untitledWindowExcludeList
        }
        
        await self.reloadHotkeys()
        
        // Refresh apps to apply new filters
        await self.refreshApps()
      }
    }
  }

  func reloadHotkeys() async {
    // Hotkeys are managed by KeyboardShortcuts package
  }

  func updateAppearance(_ appearance: AppearanceConfiguration) async throws {
    let config = configuration.copy()
    config.update(from: appearance)
    try await settingsManager.saveConfiguration(config)
    self.configuration = settingsManager.currentConfiguration
  }

  func updateBehavior(_ behavior: BehaviorConfiguration) async throws {
    let config = configuration.copy()
    config.update(from: behavior)
    try await settingsManager.saveConfiguration(config)
    self.configuration = settingsManager.currentConfiguration
    if let window {
      configureWindowIfNeeded(window)
    }
  }

  func resetToDefaults() async {
    let defaultConfig = await settingsManager.resetToDefaults()
    self.configuration = defaultConfig
  }
}
