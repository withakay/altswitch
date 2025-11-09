//
//  AccessibilityPermissionManager.swift
//  AltSwitch
//
//  Centralized manager for accessibility permission requests and state tracking
//

import AppKit
import Foundation
import Observation

/// Permission state tracking
enum PermissionState: Equatable {
  case unknown
  case checking
  case granted
  case denied
  case promptShown
}

/// Centralized manager for accessibility permissions
///
/// This manager ensures:
/// - Single prompt per app launch
/// - Coordinated permission checks across all components
/// - Observable state for UI updates
/// - Persistent tracking of user decisions
@MainActor
@Observable
final class AccessibilityPermissionManager {
  // MARK: - Singleton

  static let shared = AccessibilityPermissionManager()

  // MARK: - Observable State

  private(set) var state: PermissionState = .unknown
  private(set) var hasPromptedThisSession = false
  private(set) var lastCheckTime: Date?

  // MARK: - Private Properties

  private var monitoringTimer: Timer?
  private let userDefaults = UserDefaults.standard

  // UserDefaults keys
  private let hasPromptedKey = "AccessibilityPermission.HasPrompted"
  private let userDismissedKey = "AccessibilityPermission.UserDismissed"
  private let lastPromptDateKey = "AccessibilityPermission.LastPromptDate"

  // MARK: - Initialization

  private init() {
    // Check initial state without prompting
    updateState()

    // Set up automatic monitoring
    startMonitoring()
  }

  @MainActor deinit {
    // Clean up synchronously (deinit is not isolated to any actor)
    if let timer = monitoringTimer {
      timer.invalidate()
    }
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Public API

  /// Check if accessibility permissions are granted
  var isGranted: Bool {
    AXIsProcessTrusted()
  }

  /// Check permission status and update state (non-invasive)
  func checkStatus() {
    updateState()
  }

  /// Request accessibility permissions if not already granted
  /// Returns true if permissions are granted, false otherwise
  /// Will only show system prompt once per session
  @discardableResult
  func requestPermissionIfNeeded() -> Bool {
    let trusted = AXIsProcessTrusted()

    if trusted {
      state = .granted
      return true
    }

    // Don't prompt if we've already prompted this session
    guard !hasPromptedThisSession else {
      NSLog("AltSwitch: Permission prompt already shown this session")
      return false
    }

    // Don't prompt if user dismissed it recently (within 24 hours)
    if userHasDismissedRecently() {
      NSLog("AltSwitch: User dismissed permission prompt recently")
      state = .denied
      return false
    }

    // Show the system permission prompt
    NSLog("AltSwitch: Requesting accessibility permissions...")
    state = .promptShown

    // Use string literal to avoid concurrency warning
    let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
    let granted = AXIsProcessTrustedWithOptions(options)

    hasPromptedThisSession = true
    userDefaults.set(true, forKey: hasPromptedKey)
    userDefaults.set(Date(), forKey: lastPromptDateKey)

    updateState()

    return granted
  }

  /// Open System Settings to Privacy & Security > Accessibility
  func openSystemSettings() {
    if let url = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    {
      NSWorkspace.shared.open(url)
    }
  }

  /// User has explicitly dismissed the permission request
  func userDismissed() {
    userDefaults.set(true, forKey: userDismissedKey)
    userDefaults.set(Date(), forKey: lastPromptDateKey)
    state = .denied
  }

  /// Reset all permission tracking (useful for testing)
  func resetTracking() {
    userDefaults.removeObject(forKey: hasPromptedKey)
    userDefaults.removeObject(forKey: userDismissedKey)
    userDefaults.removeObject(forKey: lastPromptDateKey)
    hasPromptedThisSession = false
    updateState()
  }

  // MARK: - Monitoring

  /// Start automatic permission monitoring
  func startMonitoring() {
    guard monitoringTimer == nil else { return }

    // Check every 2 seconds for permission changes
    monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.updateState()
      }
    }

    // Also listen for app activation
    NotificationCenter.default.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.updateState()
      }
    }
  }

  /// Stop automatic permission monitoring
  func stopMonitoring() {
    monitoringTimer?.invalidate()
    monitoringTimer = nil
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Private Methods

  private func updateState() {
    lastCheckTime = Date()

    let trusted = AXIsProcessTrusted()

    if trusted {
      if state != .granted {
        NSLog("AltSwitch: Accessibility permissions GRANTED")
        // Clear dismissal flag when user grants permission
        userDefaults.removeObject(forKey: userDismissedKey)

        // CRITICAL: Post notification so WindowCache can refresh
        NotificationCenter.default.post(
          name: NSNotification.Name("AccessibilityPermissionGranted"),
          object: nil
        )
      }
      state = .granted
    } else {
      if hasPromptedThisSession {
        state = .denied
      } else {
        state = .unknown
      }
    }
  }

  private func userHasDismissedRecently() -> Bool {
    guard userDefaults.bool(forKey: userDismissedKey) else {
      return false
    }

    guard let lastPromptDate = userDefaults.object(forKey: lastPromptDateKey) as? Date else {
      return false
    }

    // Consider "recently" as within 24 hours
    let hoursSinceLastPrompt = Date().timeIntervalSince(lastPromptDate) / 3600
    return hoursSinceLastPrompt < 24
  }
}

// MARK: - Notification Extension

extension Notification.Name {
  static let accessibilityPermissionChanged = Notification.Name(
    "AltSwitch.accessibilityPermissionChanged")
}
