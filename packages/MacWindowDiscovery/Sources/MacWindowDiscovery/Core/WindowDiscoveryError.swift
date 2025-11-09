import Foundation

/// Errors that can occur during window discovery
public enum WindowDiscoveryError: Error, Sendable {
    // MARK: - Permission Errors

    /// Accessibility permissions are required but not granted
    case accessibilityPermissionDenied

    /// Screen recording permission required but not granted
    case screenRecordingPermissionDenied

    // MARK: - Process Errors

    /// The specified process ID is invalid or not running
    case invalidProcessID(pid_t)

    /// The specified bundle identifier was not found
    case bundleIdentifierNotFound(String)

    /// No running applications found
    case noRunningApplications

    // MARK: - API Errors

    /// CGWindowList API failed
    case cgWindowListFailed(underlying: Error?)

    /// AX API failed for specific reason
    case axAPIFailed(reason: String)

    /// Private Spaces API unavailable or failed
    case spacesAPIUnavailable

    // MARK: - Cache Errors

    /// Cache is stale and needs refresh
    case cacheStale

    /// Cache inconsistency detected
    case cacheInconsistent(details: String)
}

// MARK: - LocalizedError Conformance

extension WindowDiscoveryError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .accessibilityPermissionDenied:
            return "Accessibility permissions required. Grant in System Settings > Privacy & Security > Accessibility."
        case .screenRecordingPermissionDenied:
            return "Screen recording permission required. Grant in System Settings > Privacy & Security > Screen Recording."
        case .invalidProcessID(let pid):
            return "Invalid or terminated process ID: \(pid)"
        case .bundleIdentifierNotFound(let bundleID):
            return "No running application found with bundle identifier: \(bundleID)"
        case .noRunningApplications:
            return "No running applications found"
        case .cgWindowListFailed(let error):
            return "CGWindowList API failed: \(error?.localizedDescription ?? "Unknown error")"
        case .axAPIFailed(let reason):
            return "Accessibility API failed: \(reason)"
        case .spacesAPIUnavailable:
            return "Spaces API unavailable on this system"
        case .cacheStale:
            return "Cached data is stale and needs refresh"
        case .cacheInconsistent(let details):
            return "Cache inconsistency: \(details)"
        }
    }
}
