//
//  SystemEventInterceptor.swift
//  AltSwitch
//
//  Low-level keyboard event interception using CGEventTap
//

import AppKit
import CoreGraphics
import Foundation
import os.log

// Global C-style callback function for CGEventTap
func eventTapCallback(
  proxy: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  NSLog("AltSwitch: ⚡ eventTapCallback called! Type: \(type.rawValue)")

  // Get our interceptor instance from refcon
  guard let refcon = refcon else {
    NSLog("AltSwitch: ⚠️ No refcon in callback")
    return Unmanaged.passUnretained(event)
  }

  let interceptor = Unmanaged<SystemEventInterceptor>.fromOpaque(refcon).takeUnretainedValue()
  return interceptor.handleEvent(proxy: proxy, type: type, event: event)
}

/// Intercepts system-level keyboard events including Cmd+Tab
final class SystemEventInterceptor: @unchecked Sendable {
  // MARK: - Properties

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var isActive = false
  private let logger = Logger(subsystem: "com.thoughtsun.AltSwitch", category: "EventInterceptor")

  // Callback for handling intercepted events
  private var overrideHandler: ((HotkeyMode, TabCycleDirection, TabOverridePhase) -> Void)?
  private var defaultsObserver: NSObjectProtocol?

  // Track modifier state
  private var isCommandDown = false
  private var isOptionDown = false

  // Track in-flight override sequence
  private struct OverrideSequence {
    let mode: HotkeyMode
    let startTime: TimeInterval
    var cycleCount: Int
    var lastDirection: TabCycleDirection
  }

  private var currentSequence: OverrideSequence?

  // Override flags
  private var isCmdTabOverrideEnabled = HotkeyOverrideState().isCmdTabEnabled
  private var isAltTabOverrideEnabled = HotkeyOverrideState().isAltTabEnabled

  // MARK: - Singleton

  @MainActor
  static let shared = SystemEventInterceptor()

  private init() {
    // Permission checking is handled by AccessibilityPermissionManager
  }

  deinit {
    // Clean up synchronously
    cleanupSync()
  }

  // MARK: - Public Methods

  /// Start intercepting keyboard events
  @MainActor
  func start(overrideHandler: @escaping (HotkeyMode, TabCycleDirection, TabOverridePhase) -> Void) {
    self.overrideHandler = overrideHandler
    reloadOverrideFlags()
    registerForOverrideChanges()

    // Clear old log and start fresh
    DebugLogger.clear()
    DebugLogger.log("🚀 SystemEventInterceptor.start() called")
    DebugLogger.log("📁 Log file: \(DebugLogger.getLogPath())")
    NSLog("AltSwitch: Debug log at \(DebugLogger.getLogPath())")

    // Ensure we're on main thread
    assert(Thread.isMainThread, "Must be on main thread")
    NSLog("AltSwitch: On main thread: \(Thread.isMainThread)")

    // Delay initial check to allow app to fully initialize
    Task { @MainActor in
      // Wait for app to initialize
      DebugLogger.log("⏳ Waiting for app initialization...")
      try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second initial delay

      // In debug builds, just try to create the event tap anyway
      #if DEBUG
        DebugLogger.log(
          "🔨 DEBUG: Attempting to create event tap regardless of permission check")
        NSLog("AltSwitch: DEBUG - Creating event tap without permission check")
        setupEventTap()
        verifyEventTap()

        // After setup, check if it's actually working
        try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second
        if let eventTap = eventTap, CGEvent.tapIsEnabled(tap: eventTap) {
          DebugLogger.log("✅ Event tap created and enabled successfully")
          NSLog("AltSwitch: Event tap is working!")
        } else {
          DebugLogger.log("⚠️ Event tap creation may have failed")
          let permissionManager = AccessibilityPermissionManager.shared
          DebugLogger.log("🔍 Permission state: \(permissionManager.state)")
          // Permission prompting is handled centrally at app launch
        }
      #else
        // Production build - check permissions via centralized manager
        let permissionManager = AccessibilityPermissionManager.shared
        DebugLogger.log("🔍 Checking accessibility permissions via centralized manager...")
        DebugLogger.log("📋 Permission state: \(permissionManager.state)")

        let hasPermissions = permissionManager.isGranted

        if !hasPermissions {
          DebugLogger.log("⚠️ Initial accessibility check failed, will retry...")
          print(
            "⚠️ SystemEventInterceptor: Initial accessibility check failed, retrying...")

          // Keep checking until we get permissions
          var attempts = 0
          while attempts < 30 {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 second
            attempts += 1

            permissionManager.checkStatus()
            if permissionManager.isGranted {
              DebugLogger.log(
                "✅ Got accessibility permissions after \(attempts) attempts")
              NSLog(
                "AltSwitch: Got accessibility permissions after \(attempts) attempts"
              )

              // Setup event tap
              setupEventTap()
              verifyEventTap()
              break
            }
          }

          if !permissionManager.isGranted {
            NSLog(
              "AltSwitch: ❌ Accessibility permissions not granted after waiting period"
            )
            DebugLogger.log(
              "❌ Accessibility permissions not granted after waiting period")
          }
        } else {
          // We have permissions, setup immediately
          DebugLogger.log("✅ Have accessibility permissions on first check")
          setupEventTap()
          verifyEventTap()
        }
      #endif
    }
  }

  /// Verify the event tap is active
  @MainActor
  private func verifyEventTap() {
    NSLog("AltSwitch: Verifying event tap status...")
    NSLog("AltSwitch:   - eventTap exists: \(eventTap != nil)")
    NSLog("AltSwitch:   - isActive: \(isActive)")
    NSLog("AltSwitch:   - AXIsProcessTrusted: \(AXIsProcessTrusted())")

    if let eventTap = eventTap {
      // Check if it's enabled
      let enabled = CGEvent.tapIsEnabled(tap: eventTap)
      NSLog("AltSwitch:   - CGEvent.tapIsEnabled: \(enabled)")

      if !enabled {
        NSLog("AltSwitch: ⚠️ Event tap exists but is disabled, re-enabling...")
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
    } else {
      NSLog("AltSwitch: ❌ Event tap is nil!")
    }
  }

  /// Stop intercepting keyboard events
  @MainActor
  func stop() {
    cleanupSync()
  }

  /// Manually reload override flags (useful when settings change)
  @MainActor
  func reloadSettings() {
    NSLog("AltSwitch: Manual reload of override settings requested")
    reloadOverrideFlags()
  }

  /// Internal cleanup that can be called from deinit
  private func cleanupSync() {
    if let eventTap = eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
    }

    if let runLoopSource = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
    }

    eventTap = nil
    runLoopSource = nil
    isActive = false

    if let observer = defaultsObserver {
      NotificationCenter.default.removeObserver(observer)
      defaultsObserver = nil
    }

    overrideHandler = nil
    currentSequence = nil

    print("🧹 SystemEventInterceptor cleaned up")
  }

  // MARK: - Private Methods

  private func setupEventTap() {
    DebugLogger.log("🔧 Setting up CGEventTap...")
    logger.info("🔧 Setting up CGEventTap...")

    // Try multiple times if needed
    var attempts = 0
    while attempts < 3 {
      attempts += 1
      DebugLogger.log("🔄 CGEventTap creation attempt \(attempts)")

      // Create event mask for key down and flags changed events
      let eventMask =
        (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        | (1 << CGEventType.flagsChanged.rawValue)

      // Store self reference for callback - use unretained to avoid cycle
      let selfPointer = Unmanaged.passUnretained(self).toOpaque()

      // Create the event tap using global callback function
      // Use cgSessionEventTap - only requires Accessibility permission (not Input Monitoring)
      if let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,  // Session event tap - works with just Accessibility permission
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: eventTapCallback,  // Use global function
        userInfo: selfPointer
      ) {
        // Success! Continue with setup
        self.eventTap = eventTap

        // Create run loop source and add to MAIN run loop (not current)
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        // Always add to main run loop, regardless of current thread
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)

        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        isActive = true

        // Verify the run loop source is added
        NSLog("AltSwitch: Run loop source added to main run loop")

        logger.info("✅ SystemEventInterceptor: Event tap created and active")
        NSLog("AltSwitch: ✅ Event tap created successfully on attempt \(attempts)")
        return  // Success, exit the function

      } else {
        // Failed - no need to release since we used passUnretained

        if attempts < 3 {
          NSLog(
            "AltSwitch: CGEventTap creation failed on attempt \(attempts), retrying...")
          Thread.sleep(forTimeInterval: 0.5)  // Wait before retry
        }
      }
    }

    // All attempts failed
    logger.error("❌ Failed to create event tap after 3 attempts")
    NSLog("AltSwitch: ❌ Failed to create CGEventTap after 3 attempts!")

    // Check permissions - use direct AX call since we're not on main actor
    let trusted = AXIsProcessTrusted()
    NSLog("AltSwitch: Final check - AXIsProcessTrusted: \(trusted)")

    if !trusted {
      NSLog("AltSwitch: ❌ App is not trusted for accessibility!")
      // Permission prompting is handled centrally at app launch
      // User can manually grant permissions via System Settings
    }
  }

  func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<
    CGEvent
  >? {
    // Log every event for debugging
    DebugLogger.log("📍 Event received - Type: \(type.rawValue)")

    // Handle tap timeout
    if type == .tapDisabledByTimeout {
      print("⚠️ Event tap timed out, re-enabling...")
      DebugLogger.log("⚠️ Event tap timed out, re-enabling...")
      if let eventTap = eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return Unmanaged.passUnretained(event)
    }

    // Track modifier key states
    if type == .flagsChanged {
      let flags = event.flags
      let wasCommandDown = isCommandDown
      let wasOptionDown = isOptionDown

      isCommandDown = flags.contains(.maskCommand)
      isOptionDown = flags.contains(.maskAlternate)

      if wasCommandDown && !isCommandDown {
        finishOverrideSequence(for: .cmdTab)
      }

      if wasOptionDown && !isOptionDown {
        finishOverrideSequence(for: .altTab)
      }

      // Debug output
      if isCommandDown || isOptionDown {
        print("🔑 Modifier changed - Cmd: \(isCommandDown), Alt: \(isOptionDown)")
        DebugLogger.log("🔑 Modifier changed - Cmd: \(isCommandDown), Alt: \(isOptionDown)")
      }
    }

    // Check for Tab key press with modifiers
    if type == .keyDown {
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      let flags = event.flags

      DebugLogger.log("⌨️ Key down - Code: \(keyCode)")

      // Debug all key presses when modifiers are down
      if flags.contains(.maskCommand) || flags.contains(.maskAlternate) {
        print(
          "🔍 Key down - Code: \(keyCode), Cmd: \(flags.contains(.maskCommand)), Alt: \(flags.contains(.maskAlternate))"
        )
        DebugLogger.log(
          "🔍 Key down - Code: \(keyCode), Cmd: \(flags.contains(.maskCommand)), Alt: \(flags.contains(.maskAlternate))"
        )
      }

      // Tab key code is 48
      if keyCode == 48 {
        print(
          "📍 Tab key detected! Flags: Cmd=\(flags.contains(.maskCommand)), Alt=\(flags.contains(.maskAlternate)), Ctrl=\(flags.contains(.maskControl))"
        )
        DebugLogger.log(
          "📍 Tab key detected! Flags: Cmd=\(flags.contains(.maskCommand)), Alt=\(flags.contains(.maskAlternate)), Ctrl=\(flags.contains(.maskControl))"
        )
        DebugLogger.log(
          "🔍 Current override state - CmdTab: \(isCmdTabOverrideEnabled), AltTab: \(isAltTabOverrideEnabled)"
        )

        // We intercept if the corresponding override is enabled

        if let overrideMode = overrideMode(for: flags) {
          let direction: TabCycleDirection =
            flags.contains(.maskShift) ? .backward : .forward
          handleTabOverrideKeyDown(mode: overrideMode, direction: direction)
          return nil
        } else {
          DebugLogger.log("⚠️ Tab pressed but no override mode matched (passing through)")
          print("⚠️ Tab pressed but no override mode matched (passing through)")
        }
      }
    }

    // Pass through all other events unchanged
    return Unmanaged.passUnretained(event)
  }

  // MARK: - Debugging

  func debugEventInfo(_ event: CGEvent) {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    var flagsStr = ""
    if flags.contains(.maskCommand) { flagsStr += "Cmd " }
    if flags.contains(.maskShift) { flagsStr += "Shift " }
    if flags.contains(.maskControl) { flagsStr += "Ctrl " }
    if flags.contains(.maskAlternate) { flagsStr += "Alt " }

    print("🔍 Key event - Code: \(keyCode), Flags: \(flagsStr)")
  }

  private func reloadOverrideFlags() {
    let state = HotkeyOverrideState()
    let newCmdTabEnabled = state.isCmdTabEnabled
    let newAltTabEnabled = state.isAltTabEnabled

    let changed = (newCmdTabEnabled != isCmdTabOverrideEnabled) || (newAltTabEnabled != isAltTabOverrideEnabled)

    isCmdTabOverrideEnabled = newCmdTabEnabled
    isAltTabOverrideEnabled = newAltTabEnabled

    NSLog(
      "AltSwitch: 🔄 Override flags \(changed ? "CHANGED" : "reloaded") - CmdTab: \(isCmdTabOverrideEnabled), AltTab: \(isAltTabOverrideEnabled)"
    )
    DebugLogger.log(
      "🔄 Override flags \(changed ? "CHANGED" : "reloaded") - CmdTab: \(isCmdTabOverrideEnabled), AltTab: \(isAltTabOverrideEnabled)"
    )

    if changed {
      print("🎯 SystemEventInterceptor: Flags changed! CmdTab=\(isCmdTabOverrideEnabled), AltTab=\(isAltTabOverrideEnabled)")
    }
  }

  private func registerForOverrideChanges() {
    if defaultsObserver != nil {
      return
    }

    defaultsObserver = NotificationCenter.default.addObserver(
      forName: UserDefaults.didChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.reloadOverrideFlags()
    }
  }

  private func handleTabOverrideKeyDown(mode: HotkeyMode, direction: TabCycleDirection) {
    logOverrideCapture(mode: mode)

    let now = CFAbsoluteTimeGetCurrent()

    if var sequence = currentSequence, sequence.mode == mode {
      sequence.cycleCount += 1
      sequence.lastDirection = direction
      currentSequence = sequence

      DebugLogger.log(
        "🔁 Tab override repeated - mode: \(mode.rawValue), direction: \(direction)")
      dispatchOverride(mode: mode, direction: direction, phase: .repeated)
    } else {
      currentSequence = OverrideSequence(
        mode: mode,
        startTime: now,
        cycleCount: 0,
        lastDirection: direction
      )

      DebugLogger.log(
        "🚦 Tab override began - mode: \(mode.rawValue), direction: \(direction)")
      dispatchOverride(mode: mode, direction: direction, phase: .began)
    }
  }

  private func finishOverrideSequence(for mode: HotkeyMode) {
    guard let sequence = currentSequence, sequence.mode == mode else { return }

    let elapsed = CFAbsoluteTimeGetCurrent() - sequence.startTime
    let commit = sequence.cycleCount > 0
    DebugLogger.log(
      "🏁 Tab override ended - mode: \(mode.rawValue), cycles: \(sequence.cycleCount), elapsed: \(elapsed), commit: \(commit)"
    )

    dispatchOverride(
      mode: mode, direction: sequence.lastDirection, phase: .ended(commit: commit)
    )
    currentSequence = nil
  }

  private func dispatchOverride(
    mode: HotkeyMode, direction: TabCycleDirection, phase: TabOverridePhase
  ) {
    guard let overrideHandler else { return }
    DispatchQueue.main.async {
      overrideHandler(mode, direction, phase)
    }
  }

  private func overrideMode(for flags: CGEventFlags) -> HotkeyMode? {
    if flags.contains(.maskCommand), !flags.contains(.maskAlternate), !flags.contains(.maskControl)
    {
      return isCmdTabOverrideEnabled ? .cmdTab : nil
    }

    if flags.contains(.maskAlternate), !flags.contains(.maskCommand), !flags.contains(.maskControl)
    {
      return isAltTabOverrideEnabled ? .altTab : nil
    }

    return nil
  }

  private func logOverrideCapture(mode: HotkeyMode) {
    switch mode {
    case .cmdTab:
      logger.info("🎯 Intercepted Cmd+Tab! Consuming event...")
      DebugLogger.log("🎯 Intercepted Cmd+Tab! Consuming event...")
      NSLog("AltSwitch: INTERCEPTED CMD+TAB!")
    case .altTab:
      print("🎯 Intercepted Alt+Tab! Consuming event...")
      DebugLogger.log("🎯 Intercepted Alt+Tab! Consuming event...")
      NSLog("AltSwitch: INTERCEPTED ALT+TAB!")
    case .custom:
      break
    }
  }

  #if DEBUG
    func debugOverrideMode(for flags: CGEventFlags) -> HotkeyMode? {
      overrideMode(for: flags)
    }
  #endif
}
