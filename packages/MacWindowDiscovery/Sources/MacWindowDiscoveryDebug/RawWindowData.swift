import Foundation
import MacWindowDiscovery

/// Holds both the processed WindowInfo and raw OS-level data
struct RawWindowData: Identifiable {
    let id: UInt32 // Window ID
    let windowInfo: WindowInfo
    let cgDictionary: [String: Any] // Raw CGWindowList dictionary

    /// Convert the raw dictionary to a readable format
    var formattedRawData: [(key: String, value: String, type: String)] {
        cgDictionary.keys.sorted().map { key in
            let value = cgDictionary[key]!
            let (formattedValue, type) = formatValue(value)
            return (key: key, value: formattedValue, type: type)
        }
    }

    private func formatValue(_ value: Any) -> (String, String) {
        switch value {
        case let num as NSNumber:
            // Check if it's a boolean
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return ("\(num.boolValue)", "Bool")
            }
            // Otherwise it's a number
            return ("\(num)", type(of: num).description())

        case let str as String:
            return ("\"\(str)\"", "String")

        case let dict as [String: Any]:
            let formatted = dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            return ("{\(formatted)}", "Dictionary")

        case let arr as [Any]:
            let formatted = arr.map { "\($0)" }.joined(separator: ", ")
            return ("[\(formatted)]", "Array")

        default:
            return ("\(value)", String(describing: type(of: value)))
        }
    }
}

/// Comprehensive documentation of CGWindowList keys
enum CGWindowListKey: String, CaseIterable {
    case windowNumber = "kCGWindowNumber"
    case ownerPID = "kCGWindowOwnerPID"
    case ownerName = "kCGWindowOwnerName"
    case name = "kCGWindowName"
    case bounds = "kCGWindowBounds"
    case alpha = "kCGWindowAlpha"
    case layer = "kCGWindowLayer"
    case isOnscreen = "kCGWindowIsOnscreen"
    case memoryUsage = "kCGWindowMemoryUsage"
    case sharingState = "kCGWindowSharingState"
    case storeType = "kCGWindowStoreType"
    case workspaceID = "kCGWindowWorkspace"

    var description: String {
        switch self {
        case .windowNumber:
            return "Unique window identifier (CGWindowID)"
        case .ownerPID:
            return "Process ID of the owning application"
        case .ownerName:
            return "Name of the owning application"
        case .name:
            return "Window title from Core Graphics"
        case .bounds:
            return "Window frame in screen coordinates {X, Y, Width, Height}"
        case .alpha:
            return "Transparency level (0.0 = transparent, 1.0 = opaque)"
        case .layer:
            return "Window layer (0 = normal, higher = overlay)"
        case .isOnscreen:
            return "Whether the window is currently visible on screen"
        case .memoryUsage:
            return "Memory used by the window in bytes"
        case .sharingState:
            return "Window sharing state (0 = none, 1 = read-only, 2 = read-write)"
        case .storeType:
            return "Window backing store type"
        case .workspaceID:
            return "Workspace/Space ID (macOS internal)"
        }
    }
}
