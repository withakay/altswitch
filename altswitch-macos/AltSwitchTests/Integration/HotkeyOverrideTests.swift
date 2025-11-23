//
//  HotkeyOverrideTests.swift
//  AltSwitchTests
//
//  Regression coverage for reserved Cmd/Alt-Tab overrides.
//

import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import AltSwitch

@Suite("Hotkey Override Integration Tests")
@MainActor
struct HotkeyOverrideTests {

  // MARK: - Infrastructure

  private func synchronizeOverrides() async {
    NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: nil)
    await Task.yield()
  }

  private func resetOverrides() async {
    HotkeyCenter.shared.overrideModeDidChange(to: .custom)
    await synchronizeOverrides()
  }

  // MARK: - Tests

  @Test("Cmd+Tab override enables interceptor capture")
  func testCmdTabOverrideIntercepts() async throws {
    HotkeyCenter.shared.overrideModeDidChange(to: .cmdTab)
    await synchronizeOverrides()

    let interceptor = SystemEventInterceptor.shared
    let mode = interceptor.debugOverrideMode(for: [.maskCommand])
    #expect(mode == .cmdTab, "Cmd+Tab override should consume Command+Tab events")

    HotkeyCenter.shared.overrideModeDidChange(to: .custom)
    await synchronizeOverrides()

    let modeAfterReset = interceptor.debugOverrideMode(for: [.maskCommand])
    #expect(
      modeAfterReset == nil, "Cmd+Tab override should release Command+Tab events when disabled")

    await resetOverrides()
  }

  @Test("Alt+Tab override enables interceptor capture")
  func testAltTabOverrideIntercepts() async throws {
    HotkeyCenter.shared.overrideModeDidChange(to: .altTab)
    await synchronizeOverrides()

    let interceptor = SystemEventInterceptor.shared
    let mode = interceptor.debugOverrideMode(for: [.maskAlternate])
    #expect(mode == .altTab, "Alt+Tab override should consume Option+Tab events")

    HotkeyCenter.shared.overrideModeDidChange(to: .custom)
    await synchronizeOverrides()

    let modeAfterReset = interceptor.debugOverrideMode(for: [.maskAlternate])
    #expect(
      modeAfterReset == nil, "Alt+Tab override should release Option+Tab events when disabled")

    await resetOverrides()
  }

  @Test("Override state persists through center reboot")
  func testOverrideStatePersistence() async throws {
    HotkeyCenter.shared.overrideModeDidChange(to: .cmdTab)
    await synchronizeOverrides()

    // Simulate "reboot" by forcing the center to reapply stored state
    HotkeyCenter.shared.overrideModeDidChange(to: HotkeyOverrideState().mode)
    await synchronizeOverrides()

    let interceptor = SystemEventInterceptor.shared
    let mode = interceptor.debugOverrideMode(for: [.maskCommand])
    #expect(mode == .cmdTab, "Stored override should be re-applied after center reconfiguration")

    await resetOverrides()
  }

  @Test("Double-tap mode propagates to interceptor state")
  func testDoubleTapModeUpdatesInterceptor() async throws {
    HotkeyCenter.shared.overrideModeDidChange(to: .doubleTapOption)
    await synchronizeOverrides()

    let interceptor = SystemEventInterceptor.shared
    #expect(interceptor.debugDoubleTapModifier() == .option, "Double-tap selection should propagate to interceptor")

    HotkeyCenter.shared.overrideModeDidChange(to: .custom)
    await synchronizeOverrides()

    #expect(interceptor.debugDoubleTapModifier() == nil, "Double-tap selection should clear when returning to custom hotkeys")

    await resetOverrides()
  }
}
