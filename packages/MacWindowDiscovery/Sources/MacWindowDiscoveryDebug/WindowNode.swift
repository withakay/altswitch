import Foundation
import CoreGraphics
import MacWindowDiscovery

/// A tree node for displaying window information hierarchically
struct WindowNode: Identifiable, Hashable {
    let id: UUID
    let label: String
    let value: String?
    let children: [WindowNode]?
    let isSearchMatch: Bool
    let windowInfo: WindowInfo? // Reference to the window for inspector

    init(
        id: UUID = UUID(),
        label: String,
        value: String? = nil,
        children: [WindowNode]? = nil,
        isSearchMatch: Bool = false,
        windowInfo: WindowInfo? = nil
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.children = children
        self.isSearchMatch = isSearchMatch
        self.windowInfo = windowInfo
    }

    static func == (lhs: WindowNode, rhs: WindowNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Creates a leaf node (property with value)
    static func leaf(label: String, value: String) -> WindowNode {
        WindowNode(label: label, value: value, children: nil)
    }

    /// Creates a branch node (container with children)
    static func branch(label: String, children: [WindowNode]) -> WindowNode {
        WindowNode(label: label, value: nil, children: children)
    }

    /// Full display text for this node
    var displayText: String {
        if let value = value {
            return "\(label): \(value)"
        } else {
            return label
        }
    }

    /// Checks if this node or any of its children match the search term
    func matches(searchTerm: String) -> Bool {
        if searchTerm.isEmpty { return true }

        let lowercasedSearch = searchTerm.lowercased()

        // Check current node
        if label.lowercased().contains(lowercasedSearch) {
            return true
        }
        if let value = value, value.lowercased().contains(lowercasedSearch) {
            return true
        }

        // Check children recursively
        if let children = children {
            return children.contains { $0.matches(searchTerm: searchTerm) }
        }

        return false
    }

    /// Creates a filtered copy of this node tree based on search term
    func filtered(by searchTerm: String) -> WindowNode? {
        if searchTerm.isEmpty { return self }

        // Check if this node matches
        let nodeMatches = label.lowercased().contains(searchTerm.lowercased()) ||
                         (value?.lowercased().contains(searchTerm.lowercased()) ?? false)

        // Filter children
        let filteredChildren = children?.compactMap { $0.filtered(by: searchTerm) }

        // Include this node if it matches or has matching children
        if nodeMatches || (filteredChildren?.isEmpty == false) {
            return WindowNode(
                id: id,
                label: label,
                value: value,
                children: filteredChildren,
                isSearchMatch: nodeMatches
            )
        }

        return nil
    }
}

/// Converts WindowInfo to tree nodes
struct WindowNodeConverter {
    static func convert(windows: [WindowInfo]) -> [WindowNode] {
        windows.enumerated().map { index, window in
            WindowNode(
                label: windowTitle(for: window, index: index),
                value: nil,
                children: windowChildren(for: window),
                isSearchMatch: false,
                windowInfo: window // Pass reference for inspector
            )
        }
    }

    private static func windowTitle(for window: WindowInfo, index: Int) -> String {
        let title = window.title.isEmpty ? "Untitled" : window.title
        let appName = window.applicationName ?? "Unknown App"
        return "\(appName) - \(title)"
    }

    private static func windowChildren(for window: WindowInfo) -> [WindowNode] {
        var children: [WindowNode] = []

        // Basic properties
        children.append(.leaf(label: "id", value: String(window.id)))
        children.append(.leaf(label: "processID", value: String(window.processID)))

        if let appName = window.applicationName {
            children.append(.leaf(label: "applicationName", value: appName))
        }

        if let bundleID = window.bundleIdentifier {
            children.append(.leaf(label: "bundleIdentifier", value: bundleID))
        }

        if !window.title.isEmpty {
            children.append(.leaf(label: "title", value: window.title))
        }

        // Bounds
        children.append(.branch(
            label: "bounds",
            children: [
                .leaf(label: "x", value: String(format: "%.1f", window.bounds.origin.x)),
                .leaf(label: "y", value: String(format: "%.1f", window.bounds.origin.y)),
                .leaf(label: "width", value: String(format: "%.1f", window.bounds.size.width)),
                .leaf(label: "height", value: String(format: "%.1f", window.bounds.size.height))
            ]
        ))

        // Layer
        children.append(.leaf(label: "layer", value: String(window.layer)))

        // Alpha
        children.append(.leaf(label: "alpha", value: String(format: "%.2f", window.alpha)))

        // Boolean flags
        children.append(.branch(
            label: "state",
            children: [
                .leaf(label: "isOnScreen", value: String(window.isOnScreen)),
                .leaf(label: "isHidden", value: String(window.isHidden)),
                .leaf(label: "isMinimized", value: String(window.isMinimized)),
                .leaf(label: "isFullscreen", value: String(window.isFullscreen)),
                .leaf(label: "isFocused", value: String(window.isFocused)),
                .leaf(label: "isMainWindow", value: String(window.isMainWindow)),
                .leaf(label: "isTabbed", value: String(window.isTabbed))
            ]
        ))

        // Display information
        children.append(.branch(
            label: "display",
            children: [
                .leaf(label: "displayID", value: String(window.displayID)),
                .leaf(label: "isMainDisplay", value: String(CGDisplayIsMain(window.displayID) != 0))
            ]
        ))

        // Space information
        var spaceChildren: [WindowNode] = []
        if !window.spaceIDs.isEmpty {
            let spaceIDsStr = window.spaceIDs.map { String($0) }.joined(separator: ", ")
            spaceChildren.append(.leaf(label: "spaceIDs", value: "[\(spaceIDsStr)]"))
        }
        spaceChildren.append(.leaf(label: "isOnAllSpaces", value: String(window.isOnAllSpaces)))

        children.append(.branch(label: "spaces", children: spaceChildren))

        // AX metadata
        if let role = window.role {
            children.append(.leaf(label: "role", value: role))
        }

        if let subrole = window.subrole {
            children.append(.leaf(label: "subrole", value: subrole))
        }

        // Metadata
        let dateFormatter = ISO8601DateFormatter()
        children.append(.leaf(label: "capturedAt", value: dateFormatter.string(from: window.capturedAt)))

        return children
    }
}
