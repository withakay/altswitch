//
//  AppActivationTracker.swift
//  AltSwitch
//
//  Service for tracking when applications were last activated
//

import AppKit
import Foundation

/// Tracks application activation times for sorting by last used
@MainActor
final class AppActivationTracker {

  // MARK: - Properties

  /// Dictionary mapping bundle identifiers to their last activation times
  private var activationTimes: [String: Date] = [:]

  /// UserDefaults key for persisting activation times
  private let userDefaultsKey = "AppActivationTimes"

  /// Maximum number of activation times to store (to prevent unbounded growth)
  private let maxStoredTimes = 100

  // MARK: - Initialization

  init() {
    loadPersistedTimes()
    setupNotificationObservers()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // MARK: - Public Methods

  /// Get the last activation time for a bundle identifier
  func lastActivationTime(for bundleIdentifier: String) -> Date {
    return activationTimes[bundleIdentifier] ?? Date.distantPast
  }

  /// Manually record an activation time (useful for testing or external triggers)
  func recordActivation(for bundleIdentifier: String, at time: Date = Date()) {
    activationTimes[bundleIdentifier] = time
    persistTimes()
  }

  /// Get all tracked apps sorted by activation time (most recent first)
  func sortedBundleIdentifiers() -> [String] {
    return activationTimes.keys.sorted { id1, id2 in
      let time1 = activationTimes[id1] ?? Date.distantPast
      let time2 = activationTimes[id2] ?? Date.distantPast
      return time1 > time2
    }
  }

  /// Sort a list of AppInfo objects by last activation time
  func sorted(_ apps: [AppInfo]) -> [AppInfo] {
    return apps.sorted { app1, app2 in
      let time1 = lastActivationTime(for: app1.bundleIdentifier)
      let time2 = lastActivationTime(for: app2.bundleIdentifier)

      // Currently active app should always be first
      if app1.isActive && !app2.isActive {
        return true
      } else if !app1.isActive && app2.isActive {
        return false
      }

      // Then sort by last activation time (most recent first)
      return time1 > time2
    }
  }

  // MARK: - Private Methods

  private func setupNotificationObservers() {
    // Listen for app activation notifications
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(applicationDidActivate(_:)),
      name: NSWorkspace.didActivateApplicationNotification,
      object: nil
    )

    // Also track when apps are launched
    NSWorkspace.shared.notificationCenter.addObserver(
      self,
      selector: #selector(applicationDidLaunch(_:)),
      name: NSWorkspace.didLaunchApplicationNotification,
      object: nil
    )
  }

  @objc private func applicationDidActivate(_ notification: Notification) {
    guard
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
      let bundleIdentifier = app.bundleIdentifier
    else {
      return
    }

    // Don't track our own app or system processes
    if bundleIdentifier == Bundle.main.bundleIdentifier || isSystemProcess(bundleIdentifier) {
      return
    }

    recordActivation(for: bundleIdentifier)
  }

  @objc private func applicationDidLaunch(_ notification: Notification) {
    guard
      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
      let bundleIdentifier = app.bundleIdentifier
    else {
      return
    }

    // Don't track our own app or system processes
    if bundleIdentifier == Bundle.main.bundleIdentifier || isSystemProcess(bundleIdentifier) {
      return
    }

    // Record launch time only if we don't already have a recent activation time
    let existingTime = activationTimes[bundleIdentifier] ?? Date.distantPast
    if Date().timeIntervalSince(existingTime) > 5 {  // Only update if more than 5 seconds ago
      recordActivation(for: bundleIdentifier)
    }
  }

  private func isSystemProcess(_ bundleIdentifier: String) -> Bool {
    let systemProcesses: Set<String> = [
      "com.apple.dock",
      "com.apple.WindowManager",
      "com.apple.controlcenter",
      "com.apple.Spotlight",
      "com.apple.notificationcenterui",
      "com.apple.systemuiserver",
      "com.apple.finder",  // Usually keep this for user access
    ]
    return systemProcesses.contains(bundleIdentifier)
  }

  private func loadPersistedTimes() {
    guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
      let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data)
    else {
      return
    }

    // Convert TimeInterval back to Date
    activationTimes = decoded.mapValues { Date(timeIntervalSince1970: $0) }

    // Clean up old entries to prevent unbounded growth
    cleanupOldEntries()
  }

  private func persistTimes() {
    // Convert dates to TimeInterval for JSON encoding
    let timeIntervals = activationTimes.mapValues { $0.timeIntervalSince1970 }

    guard let data = try? JSONEncoder().encode(timeIntervals) else {
      print("Failed to encode activation times")
      return
    }

    UserDefaults.standard.set(data, forKey: userDefaultsKey)
  }

  private func cleanupOldEntries() {
    // If we have too many entries, keep only the most recent ones
    if activationTimes.count > maxStoredTimes {
      let sorted = activationTimes.sorted { $0.value > $1.value }
      let mostRecent = Array(sorted.prefix(maxStoredTimes))
      let toKeep = Dictionary(uniqueKeysWithValues: mostRecent)
      activationTimes = toKeep
      persistTimes()
    }
  }
}
