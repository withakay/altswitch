//
//  HotkeyCenter.swift
//  AltSwitch
//
//  Global hotkey management using KeyboardShortcuts package
//

import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI

/// Long-lived global hotkey center that manages all keyboard shortcuts
@MainActor
@Observable
final class HotkeyCenter {

  // Singleton for shared access
  private static var _shared: HotkeyCenter?
  
  static var shared: HotkeyCenter {
    guard let instance = _shared else {
      fatalError("HotkeyCenter.shared accessed before configuration. Call configure(with:) first.")
    }
    return instance
  }
  
  /// Configure the shared instance with configuration
  static func configure(with configuration: Configuration) {
    _shared = HotkeyCenter(configuration: configuration)
  }

  private var currentCyclingMode: HotkeyMode?
  private var commitSelectionTask: Task<Void, Never>?

  // Track registration state
  private var hasSetupHotkeys = false
  
  // Configuration for hotkey initialization delay
  private let configuration: Configuration

  // Event interceptor for Cmd+Tab
  private let eventInterceptor = SystemEventInterceptor.shared
  private var overrideState = HotkeyOverrideState()

  private init(configuration: Configuration) {
    self.configuration = configuration
    NSLog("AltSwitch: HotkeyCenter.init() called")
    print("🔧 HotkeyCenter.init() called")

    // Delay setup until after app initialization
    Task { @MainActor in
      NSLog("AltSwitch: HotkeyCenter init Task started")
      print("🔧 HotkeyCenter init Task started")

      // Configurable delay to ensure AppDelegate is ready
      let delayNanoseconds = UInt64(configuration.hotkeyInitDelay * 1_000_000_000)
      try? await Task.sleep(nanoseconds: delayNanoseconds)

      NSLog("AltSwitch: HotkeyCenter calling setup methods")
      print("🔧 HotkeyCenter calling setup methods")

      setupHotkeyListeners()
      setupFocusObservers()
      setupEventInterceptor()
      applyStoredOverrideState()

      NSLog("AltSwitch: HotkeyCenter init complete")
      print("✅ HotkeyCenter init complete")
    }
  }

  /// Public method to setup or re-setup hotkeys (for testing)
  func setupHotkeys() async {
    if !hasSetupHotkeys {
      setupHotkeyListeners()
      hasSetupHotkeys = true
    }
  }

  /// Setup observers for app focus changes
  private func setupFocusObservers() {
    // Monitor app activation/deactivation
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidBecomeActive),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidResignActive),
      name: NSApplication.didResignActiveNotification,
      object: nil
    )
  }

  @objc private func appDidBecomeActive(_ notification: Notification) {
    print("🟢 App became active - hotkeys should be working")
    verifyHotkeyRegistration()
  }

  @objc private func appDidResignActive(_ notification: Notification) {
    print("🔴 App resigned active - checking if hotkeys still work...")
    verifyHotkeyRegistration()
  }

  private func verifyHotkeyRegistration() {
    if let main = KeyboardShortcuts.getShortcut(for: .showHideAltSwitch) {
      print("   Main hotkey still registered: \(main)")
    } else {
      print("   ⚠️ Main hotkey lost registration!")
    }

    // Check event interceptor status
    print("   Event interceptor active for Cmd+Tab and Alt+Tab")
  }

  /// Setup CGEventTap-based interceptor for Cmd+Tab and Alt+Tab
  private func setupEventInterceptor() {
    print("🔧 Setting up system event interceptor for Cmd+Tab and Alt+Tab...")
    NSLog("AltSwitch: HotkeyCenter.setupEventInterceptor() called")

    eventInterceptor.start { [weak self] mode, direction, phase in
      self?.processTabOverride(mode: mode, direction: direction, phase: phase)
    }

    NSLog("AltSwitch: HotkeyCenter.setupEventInterceptor() completed")
  }

  /// Set up all global hotkey listeners
  private func setupHotkeyListeners() {
    print("🔧 Setting up hotkey listeners...")

    // Check if running as LSUIElement
    let isUIElement = Bundle.main.object(forInfoDictionaryKey: "LSUIElement") as? Bool ?? false
    print("   LSUIElement: \(isUIElement)")
    print("   App activation policy: \(NSApp.activationPolicy().rawValue)")

    // Main show/hide hotkey (custom user-defined)
    KeyboardShortcuts.onKeyUp(for: .showHideAltSwitch) { [weak self] in
      print("🔥 Main hotkey triggered!")
      self?.handleShowHideAltSwitch()
    }

    // Note: Alt+Tab and Cmd+Tab will be handled by SystemEventInterceptor
    // We'll keep these registrations for fallback/testing but they won't work for system shortcuts

    // Log registered shortcuts
    if let main = KeyboardShortcuts.getShortcut(for: .showHideAltSwitch) {
      print("✅ Main hotkey registered: \(main)")
    } else {
      print("❌ Main hotkey not registered")
    }
  }

  func overrideModeDidChange(to mode: HotkeyMode) {
    NSLog("AltSwitch: overrideModeDidChange -> \(mode.rawValue)")
    overrideState.mode = mode
    overrideState.isAltTabEnabled = (mode == .altTab)
    overrideState.isCmdTabEnabled = (mode == .cmdTab)

    if mode == .custom {
      KeyboardShortcuts.enable(.showHideAltSwitch)
    } else {
      KeyboardShortcuts.disable(.showHideAltSwitch)
    }

    currentCyclingMode = (mode == .custom) ? nil : mode

    // CRITICAL: Force SystemEventInterceptor to reload settings immediately
    Task { @MainActor in
      eventInterceptor.reloadSettings()
    }
  }

  private func handleShowHideAltSwitch() {
    NSLog("AltSwitch: handleShowHideAltSwitch called")

    guard let delegate = AppDelegate.shared else {
      NSLog("AltSwitch: ERROR - No AppDelegate.shared found")
      print("AppDelegate not available")
      return
    }

    guard let mainViewModel = delegate.mainViewModel else {
      NSLog("AltSwitch: ERROR - No MainViewModel in AppDelegate")
      print("MainViewModel not available")
      return
    }

    NSLog("AltSwitch: Calling toggleVisibility")
    mainViewModel.toggleVisibility()
  }

  private func applyStoredOverrideState() {
    overrideState = HotkeyOverrideState()
    let mode = overrideState.mode
    overrideState.isAltTabEnabled = (mode == .altTab)
    overrideState.isCmdTabEnabled = (mode == .cmdTab)
    currentCyclingMode = (mode == .custom) ? nil : mode

    if mode == .custom {
      KeyboardShortcuts.enable(.showHideAltSwitch)
    } else {
      KeyboardShortcuts.disable(.showHideAltSwitch)
    }
  }

  @MainActor
  private func processTabOverride(
    mode: HotkeyMode,
    direction: TabCycleDirection,
    phase: TabOverridePhase
  ) {
    NSLog(
      "AltSwitch: processTabOverride mode=\(mode.rawValue) direction=\(direction) phase=\(phase)")
    currentCyclingMode = mode

    let enableCycling = UserDefaults.standard.object(forKey: "EnableCycling") as? Bool ?? true
    guard let delegate = AppDelegate.shared else {
      NSLog("AltSwitch: ERROR - No AppDelegate.shared for tab override")
      return
    }

    guard let mainViewModel = delegate.mainViewModel else {
      NSLog("AltSwitch: ERROR - No MainViewModel for tab override")
      return
    }

    switch phase {
    case .began:
      commitSelectionTask?.cancel()
      if !enableCycling {
        NSLog("AltSwitch: Cycling disabled, toggling visibility")
        handleShowHideAltSwitch()
        return
      }
      ensureWindowVisible(using: mainViewModel)

    case .repeated:
      guard enableCycling else { return }
      ensureWindowVisible(using: mainViewModel)
      if direction == .forward {
        mainViewModel.cycleForward()
      } else {
        mainViewModel.cycleBackward()
      }

    case .ended(let commit):
      guard enableCycling else { return }
      commitSelectionTask?.cancel()

      if commit {
        NSLog("AltSwitch: Committing selection on override end")
        let viewModel = mainViewModel
        commitSelectionTask = Task { [weak self] in
          await viewModel.switchToSelectedApp()
          viewModel.hide()
          self?.commitSelectionTask = nil
        }
      } else {
        NSLog("AltSwitch: Override ended without commit, keeping window visible")
        commitSelectionTask = nil
      }
    }
  }

  @MainActor
  private func ensureWindowVisible(using viewModel: MainViewModel) {
    let mainWindowVisible =
      NSApp.windows.first(where: { $0.identifier?.rawValue == "main" })?.isVisible ?? false

    if !viewModel.isVisible || !mainWindowVisible {
      NSLog("AltSwitch: Ensuring window is visible")
      viewModel.show()
    }
  }
}
