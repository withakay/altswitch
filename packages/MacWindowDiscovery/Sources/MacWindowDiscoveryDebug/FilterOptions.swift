import Foundation
import CoreGraphics
import MacWindowDiscovery

/// Filter options for the debug UI
struct FilterOptions {
    // Presets
    var preset: FilterPreset = .complete

    // Size filters
    var useMinimumSize: Bool = false
    var minimumSize: CGSize = CGSize(width: 100, height: 50)

    // Visual filters
    var normalLayerOnly: Bool = false
    var useMinimumAlpha: Bool = false
    var minimumAlpha: Double = 0.9

    // State filters
    var includeHidden: Bool = true
    var includeMinimized: Bool = true

    // Space filters
    var includeInactiveSpaces: Bool = true

    // Title requirements
    var requireTitle: Bool = false
    var requireProperSubrole: Bool = false

    // Application filters
    var excludeSystemProcesses: Bool = false

    // Performance
    var useAccessibilityAPI: Bool = true

    /// Convert to WindowDiscoveryOptions
    func toWindowDiscoveryOptions() -> WindowDiscoveryOptions {
        WindowDiscoveryOptions(
            minimumSize: useMinimumSize ? minimumSize : .zero,
            normalLayerOnly: normalLayerOnly,
            minimumAlpha: useMinimumAlpha ? minimumAlpha : 0.0,
            includeHidden: includeHidden,
            includeMinimized: includeMinimized,
            includeInactiveSpaces: includeInactiveSpaces,
            requireTitle: requireTitle,
            requireProperSubrole: requireProperSubrole,
            bundleIdentifierWhitelist: nil,
            bundleIdentifierBlacklist: [],
            excludeSystemProcesses: excludeSystemProcesses,
            useAccessibilityAPI: useAccessibilityAPI,
            includeSpaceInfo: true
        )
    }

    /// Apply a preset
    mutating func applyPreset(_ preset: FilterPreset) {
        self.preset = preset

        switch preset {
        case .raw:
            // Show everything, no filters
            useMinimumSize = false
            normalLayerOnly = false
            useMinimumAlpha = false
            includeHidden = true
            includeMinimized = true
            includeInactiveSpaces = true
            requireTitle = false
            requireProperSubrole = false
            excludeSystemProcesses = false
            useAccessibilityAPI = true

        case .complete:
            // Complete preset from library
            useMinimumSize = false
            normalLayerOnly = false
            useMinimumAlpha = false
            includeHidden = true
            includeMinimized = true
            includeInactiveSpaces = true
            requireTitle = false
            requireProperSubrole = false
            excludeSystemProcesses = false
            useAccessibilityAPI = true

        case .default:
            // Default preset from library
            useMinimumSize = true
            minimumSize = CGSize(width: 100, height: 50)
            normalLayerOnly = true
            useMinimumAlpha = true
            minimumAlpha = 0.9
            includeHidden = false
            includeMinimized = true
            includeInactiveSpaces = true
            requireTitle = false
            requireProperSubrole = true
            excludeSystemProcesses = true
            useAccessibilityAPI = true

        case .fast:
            // Fast preset from library (no AX)
            useMinimumSize = true
            minimumSize = CGSize(width: 50, height: 25)
            normalLayerOnly = false
            useMinimumAlpha = true
            minimumAlpha = 0.5
            includeHidden = true
            includeMinimized = true
            includeInactiveSpaces = true
            requireTitle = false
            requireProperSubrole = false
            excludeSystemProcesses = false
            useAccessibilityAPI = false

        case .cli:
            // CLI preset from library
            useMinimumSize = true
            minimumSize = CGSize(width: 100, height: 50)
            normalLayerOnly = true
            useMinimumAlpha = true
            minimumAlpha = 0.9
            includeHidden = false
            includeMinimized = true
            includeInactiveSpaces = false
            requireTitle = false
            requireProperSubrole = true
            excludeSystemProcesses = true
            useAccessibilityAPI = true

        case .custom:
            // Keep current settings
            break
        }
    }
}

enum FilterPreset: String, CaseIterable, Identifiable {
    case raw = "Raw"
    case complete = "Complete"
    case `default` = "Default"
    case fast = "Fast"
    case cli = "CLI"
    case custom = "Custom"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .raw:
            return "All windows, no filters"
        case .complete:
            return "All windows, full metadata"
        case .default:
            return "Standard app windows"
        case .fast:
            return "Fast, no AX API"
        case .cli:
            return "Active space only"
        case .custom:
            return "Custom settings"
        }
    }
}
