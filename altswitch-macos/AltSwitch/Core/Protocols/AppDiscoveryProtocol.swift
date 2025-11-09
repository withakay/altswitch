//
//  AppDiscoveryProtocol.swift
//  AltSwitch
//
//  Created by Jack Rutherford on 25/09/2025.
//

import Foundation
import MacWindowDiscovery

/// Protocol for discovering running applications and their windows
protocol AppDiscoveryProtocol: Sendable {
  /// Fetch all currently running applications
  @MainActor func fetchRunningApps(showIndividualWindows: Bool) async throws -> [AppInfo]

  /// Refresh window information for a specific application
  @MainActor func refreshWindows(for app: AppInfo) async throws -> [MacWindowDiscovery.WindowInfo]

  /// Generate debug information for all windows and save to file
  @MainActor func dumpWindowDebugInfo() async throws -> URL

  /// Set the callback to invoke when the underlying cache changes
  ///
  /// This allows subscribers to be notified of app launches, terminations,
  /// and window changes without polling.
  ///
  /// - Parameter callback: Closure to invoke on MainActor when cache changes
  @MainActor func onCacheDidChange(_ callback: @escaping @MainActor () -> Void)
}
