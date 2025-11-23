//
//  ConfigurationDefaultsTests.swift
//  AltSwitchTests
//

import Testing

@testable import AltSwitch

@Suite("Configuration defaults")
struct ConfigurationDefaultsTests {

  @Test("Provides sensible defaults")
  func validatesDefaultConfiguration() {
    let config = Configuration()

    #expect(config.maxResults == 10)
    #expect(config.windowPosition == .center)
    #expect(config.appearanceDelay == 0.1)
    #expect(config.searchDelay == 0.05)
    #expect(config.hotkeyInitDelay == 0.1)

    #expect(config.showHideHotkey == KeyCombo.showHide)
    #expect(config.settingsHotkey == nil || config.settingsHotkey == KeyCombo.settings)
    #expect(config.refreshHotkey == nil || config.refreshHotkey == KeyCombo.refresh)
  }
}
