import Foundation
import CoreGraphics
import ApplicationServices

/// Concrete implementation of AXWindowProviderProtocol using AXUIElement
public struct AXWindowProvider: AXWindowProviderProtocol {

    public init() {}

    nonisolated public func buildWindowLookup(
        for pid: pid_t,
        bundleIdentifier: String
    ) -> [CGWindowID: AXWindowInfo] {
        // Check permissions first
        guard AXIsProcessTrusted() else {
            print("⚠️  Accessibility permissions not granted, skipping AX enrichment for \(bundleIdentifier)")
            return [:]
        }

        // Create application AXUIElement
        let appElement = AXUIElementCreateApplication(pid)

        // Get main window ID (if available)
        let mainWindowID = getMainWindowID(from: appElement)

        // Get windows array
        guard let windows = getWindowsArray(from: appElement) else {
            return [:]
        }

        // Build lookup table
        var lookup: [CGWindowID: AXWindowInfo] = [:]

        for windowElement in windows {
            // Get window ID (required for matching)
            guard let windowID = getWindowID(from: windowElement) else {
                continue
            }

            // Check if this is the main window
            let isMainWindow = mainWindowID != nil && windowID == mainWindowID

            // Extract window state
            let info = extractWindowInfo(from: windowElement, isMainWindow: isMainWindow)
            lookup[windowID] = info
        }

        return lookup
    }

    // MARK: - Private Helpers

    private func getWindowsArray(from appElement: AXUIElement) -> [AXUIElement]? {
        // Try standard windows attribute first
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &value
        )

        if result == .success, let windowsArray = value as? [AXUIElement], !windowsArray.isEmpty {
            return windowsArray
        }

        // Fallback: Some apps (like Finder) don't expose windows via kAXWindowsAttribute
        // Instead, windows are direct children with role AXWindow
        var childrenValue: CFTypeRef?
        let childrenResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXChildrenAttribute as CFString,
            &childrenValue
        )

        guard childrenResult == .success,
              let children = childrenValue as? [AXUIElement] else {
            return nil
        }

        // Filter children for AXWindow role
        let windows = children.filter { child in
            let role: String? = getAttribute(child, kAXRoleAttribute)
            return role == "AXWindow"
        }

        return windows.isEmpty ? nil : windows
    }

    private func getMainWindowID(from appElement: AXUIElement) -> CGWindowID? {
        // Get the main window element
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXMainWindowAttribute as CFString,
            &value
        )

        guard result == .success, let value else {
            return nil
        }

        // Cast to AXUIElement (force cast is safe after successful AXUIElementCopyAttributeValue)
        let mainWindowElement = value as! AXUIElement

        // Get the CGWindowID from the main window element
        return getWindowID(from: mainWindowElement)
    }

    private func getWindowID(from windowElement: AXUIElement) -> CGWindowID? {
        // Try to get CGWindowID from AXUIElement
        var windowID: CGWindowID = 0
        let result = _AXUIElementGetWindow(windowElement, &windowID)

        guard result == .success else {
            return nil
        }

        return windowID
    }

    private func extractWindowInfo(from windowElement: AXUIElement, isMainWindow: Bool) -> AXWindowInfo {
        // Detect if window is tabbed
        let isTabbed = detectIfTabbed(windowElement)

        return AXWindowInfo(
            isMinimized: getAttribute(windowElement, kAXMinimizedAttribute) ?? false,
            isHidden: getAttribute(windowElement, kAXHiddenAttribute) ?? false,
            isFullscreen: getAttribute(windowElement, "AXFullScreen") ?? false,
            isFocused: getAttribute(windowElement, kAXFocusedAttribute) ?? false,
            isMainWindow: isMainWindow,
            isTabbed: isTabbed,
            title: getAttribute(windowElement, kAXTitleAttribute),
            role: getAttribute(windowElement, kAXRoleAttribute),
            subrole: getAttribute(windowElement, kAXSubroleAttribute)
        )
    }

    private func detectIfTabbed(_ windowElement: AXUIElement) -> Bool {
        // Define AXToolbar attribute string (kAXToolbarAttribute not available in newer SDKs)
        let toolbarAttribute = "AXToolbar"

        // Method 1: Check if window has a toolbar with tab buttons
        // Windows with tabs typically have AXToolbar with AXRadioButton elements for tabs
        if let toolbar: AXUIElement = getAttribute(windowElement, toolbarAttribute) {
            // Check if toolbar has tab-like buttons
            if let buttons: [AXUIElement] = getAttribute(toolbar, kAXChildrenAttribute) {
                // If there are radio buttons in the toolbar, likely tabs
                let hasTabButtons = buttons.contains { button in
                    let role: String? = getAttribute(button, kAXRoleAttribute)
                    let subrole: String? = getAttribute(button, kAXSubroleAttribute)
                    return role == "AXRadioButton" || subrole == "AXTabButton"
                }
                if hasTabButtons {
                    return true
                }
            }
        }

        // Method 2: Check for explicit tabs attribute
        // Some windows expose tabs directly
        if let tabs: [AXUIElement] = getAttribute(windowElement, "AXTabs") {
            return !tabs.isEmpty
        }

        // Method 3: Check if parent has tabs
        if let parent: AXUIElement = getAttribute(windowElement, kAXParentAttribute) {
            if let tabs: [AXUIElement] = getAttribute(parent, "AXTabs") {
                return !tabs.isEmpty
            }
        }

        return false
    }

    private func getAttribute<T>(
        _ element: AXUIElement,
        _ attribute: String
    ) -> T? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard result == .success else {
            return nil
        }

        return value as? T
    }
}

// Private AX declaration moved to AX/PrivateAX.swift to avoid redeclaration.
