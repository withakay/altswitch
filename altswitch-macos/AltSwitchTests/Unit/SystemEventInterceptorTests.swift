//
//  SystemEventInterceptorTests.swift
//  AltSwitchTests
//

import Foundation
import Testing

@testable import AltSwitch

@Suite("SystemEventInterceptor settings reload")
@MainActor
struct SystemEventInterceptorTests {

  @Test("Reload picks up double-tap mode and resets detector on change")
  func reloadUpdatesDoubleTapSettings() {
    let interceptor = SystemEventInterceptor.shared
    let suiteName = "SystemEventInterceptorTests-\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      Issue.record("Failed to create isolated UserDefaults suite")
      return
    }
    defaults.removePersistentDomain(forName: suiteName)

    interceptor.debugSetOverrideStateProvider { HotkeyOverrideState(defaults: defaults) }
    interceptor.debugSetOverrideFlags(cmdTabEnabled: false, altTabEnabled: false, doubleTap: nil)

    var resetCount = 0
    interceptor.debugSetDoubleTapResetHandler { resetCount += 1 }

    // Initial load should not reset since nothing changed
    interceptor.reloadSettings()
    #expect(resetCount == 0)
    #expect(interceptor.debugDoubleTapModifier() == nil)

    // Enable a double-tap mode and ensure it is applied and resets detector
    defaults.set(HotkeyMode.doubleTapOption.rawValue, forKey: "HotkeyMode")
    interceptor.reloadSettings()
    #expect(interceptor.debugDoubleTapModifier() == .option)
    #expect(resetCount == 1)

    // Re-run without changes should not reset again
    interceptor.reloadSettings()
    #expect(resetCount == 1)

    // Switching back to custom clears double-tap and triggers another reset
    defaults.set(HotkeyMode.custom.rawValue, forKey: "HotkeyMode")
    interceptor.reloadSettings()
    #expect(interceptor.debugDoubleTapModifier() == nil)
    #expect(resetCount == 2)

    interceptor.debugSetDoubleTapResetHandler(nil)
    interceptor.debugResetOverrideStateProvider()
    interceptor.debugSetOverrideFlags(cmdTabEnabled: false, altTabEnabled: false, doubleTap: nil)
    defaults.removePersistentDomain(forName: suiteName)
  }
}
