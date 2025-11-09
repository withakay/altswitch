//
//  ActivationQueue.swift
//  MacWindowSwitch
//
//  Background operation queue for window activation commands
//  Ported from alt-tab-macos BackgroundWork.swift
//

import Foundation

/// Manages background queues for window activation operations
///
/// This class provides dedicated operation queues for window activation commands,
/// matching the proven approach from alt-tab-macos. Commands are executed on
/// background threads with high priority (.userInteractive QoS) to ensure
/// responsive window switching.
///
/// **Threading Model:**
/// - Max 4 concurrent activation operations
/// - High priority (.userInteractive) for responsiveness
/// - Operations don't block the main thread
/// - Retry logic built into individual operations
final class ActivationQueue: @unchecked Sendable {

    /// Shared instance for activation operations
    nonisolated(unsafe) static let shared = ActivationQueue()

    /// Queue for accessibility commands (focus, activate, etc.)
    ///
    /// Configuration matches alt-tab-macos:
    /// - Quality of Service: .userInteractive (highest priority)
    /// - Max Concurrent Operations: 4
    /// - Thread-safe for concurrent access
    ///
    /// Calls to focus/close/minimize windows are tried once. If they timeout,
    /// we don't retry as the OS seems to still execute them even if the call timed out.
    private(set) var accessibilityCommandsQueue: OperationQueue

    private init() {
        // Initialize queue with same settings as alt-tab-macos
        accessibilityCommandsQueue = OperationQueue()
        accessibilityCommandsQueue.name = "com.MacWindowSwitch.accessibilityCommands"
        accessibilityCommandsQueue.qualityOfService = .userInteractive
        accessibilityCommandsQueue.maxConcurrentOperationCount = 4
    }

    /// Add an activation operation to the queue
    ///
    /// - Parameter block: The activation operation to execute
    func addActivationOperation(_ block: @escaping @Sendable () -> Void) {
        accessibilityCommandsQueue.addOperation(block)
    }
}
