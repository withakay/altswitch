import Foundation
import AppKit

/// Monitors system events for cache invalidation
///
/// Observes NSWorkspace notifications to detect when applications
/// launch, terminate, hide, unhide, or activate, and triggers
/// cache invalidation accordingly.
@MainActor
final class WindowEventMonitor {

    // MARK: - Properties

    private let cache: WindowCache
    private var observers: [NSObjectProtocol] = []
    private let notificationCenter: NotificationCenter

    typealias InvalidationHandler = @Sendable (InvalidationEvent) -> Void
    private var customHandlers: [InvalidationHandler] = []

    // MARK: - Initialization

    /// Create a new event monitor
    /// - Parameters:
    ///   - cache: The cache to invalidate on events
    ///   - notificationCenter: Notification center to observe (defaults to NSWorkspace shared)
    init(
        cache: WindowCache,
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
    ) {
        self.cache = cache
        self.notificationCenter = notificationCenter
    }

    // Note: Call stop() before deallocation to clean up observers

    // MARK: - Monitoring

    /// Start monitoring system events
    func start() {
        // App launch
        let launchObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            // Extract data synchronously from notification
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let event = InvalidationEvent(
                type: .appLaunch,
                processID: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier
            )
            Task { @MainActor in
                await self.invalidate(event)
            }
        }
        observers.append(launchObserver)

        // App termination
        let terminateObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let event = InvalidationEvent(
                type: .appTerminate,
                processID: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier
            )
            Task { @MainActor in
                await self.invalidate(event)
            }
        }
        observers.append(terminateObserver)

        // App hide
        let hideObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didHideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let event = InvalidationEvent(
                type: .appHide,
                processID: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier
            )
            Task { @MainActor in
                await self.invalidate(event)
            }
        }
        observers.append(hideObserver)

        // App unhide
        let unhideObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didUnhideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let event = InvalidationEvent(
                type: .appUnhide,
                processID: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier
            )
            Task { @MainActor in
                await self.invalidate(event)
            }
        }
        observers.append(unhideObserver)

        // App activate
        let activateObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            let event = InvalidationEvent(
                type: .appActivate,
                processID: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier
            )
            Task { @MainActor in
                await self.invalidate(event)
            }
        }
        observers.append(activateObserver)

        // Space change
        let spaceChangeObserver = notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let event = InvalidationEvent(
                type: .spaceChange,
                processID: nil,
                bundleIdentifier: nil
            )
            Task { @MainActor in
                await self.invalidate(event)
            }
        }
        observers.append(spaceChangeObserver)
    }

    /// Stop monitoring system events
    func stop() {
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    /// Add a custom invalidation handler
    func addHandler(_ handler: @escaping InvalidationHandler) {
        customHandlers.append(handler)
    }

    // MARK: - Event Handlers

    private func invalidate(_ event: InvalidationEvent) async {
        // Invalidate cache based on event type
        switch event.type {
        case .appLaunch, .appTerminate:
            // Complete invalidation for launch/terminate
            if let bundleID = event.bundleIdentifier {
                await cache.invalidateBundleIdentifier(bundleID)
            }
            if let pid = event.processID {
                await cache.invalidateProcess(pid)
            }

        case .appHide, .appUnhide, .appActivate:
            // Partial invalidation - only affects visibility/focus
            if let bundleID = event.bundleIdentifier {
                await cache.invalidateBundleIdentifier(bundleID)
            }

        case .spaceChange:
            // Space changes affect which windows are visible
            // Invalidate entire cache to refresh window lists
            await cache.clear()
        }

        // Notify custom handlers
        for handler in customHandlers {
            handler(event)
        }
    }
}

// MARK: - Invalidation Event

/// Represents a system event that requires cache invalidation
public struct InvalidationEvent: Sendable {
    public let type: EventType
    public let processID: pid_t?
    public let bundleIdentifier: String?

    public enum EventType: Sendable {
        case appLaunch
        case appTerminate
        case appHide
        case appUnhide
        case appActivate
        case spaceChange
    }
}
