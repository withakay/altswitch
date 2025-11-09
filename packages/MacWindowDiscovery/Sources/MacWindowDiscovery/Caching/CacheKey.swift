import Foundation

/// Represents what is being cached
enum CacheKey: Hashable, Sendable {
    /// All windows with specific options
    case allWindows(options: WindowDiscoveryOptions)

    /// Windows for a specific process
    case processID(pid_t, options: WindowDiscoveryOptions)

    /// Windows for a specific bundle identifier
    case bundleIdentifier(String, options: WindowDiscoveryOptions)

    // Custom Hashable implementation to handle WindowDiscoveryOptions
    func hash(into hasher: inout Hasher) {
        switch self {
        case .allWindows(let options):
            hasher.combine(0)
            hasher.combine(options.hashValue)
        case .processID(let pid, let options):
            hasher.combine(1)
            hasher.combine(pid)
            hasher.combine(options.hashValue)
        case .bundleIdentifier(let bundleID, let options):
            hasher.combine(2)
            hasher.combine(bundleID)
            hasher.combine(options.hashValue)
        }
    }

    static func == (lhs: CacheKey, rhs: CacheKey) -> Bool {
        switch (lhs, rhs) {
        case (.allWindows(let lhsOptions), .allWindows(let rhsOptions)):
            return lhsOptions == rhsOptions
        case (.processID(let lhsPid, let lhsOptions), .processID(let rhsPid, let rhsOptions)):
            return lhsPid == rhsPid && lhsOptions == rhsOptions
        case (.bundleIdentifier(let lhsBundle, let lhsOptions), .bundleIdentifier(let rhsBundle, let rhsOptions)):
            return lhsBundle == rhsBundle && lhsOptions == rhsOptions
        default:
            return false
        }
    }
}
