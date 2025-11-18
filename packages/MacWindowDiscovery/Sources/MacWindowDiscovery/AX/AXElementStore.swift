import Foundation
import ApplicationServices
import CoreGraphics

/// Thread-confined AX element cache with advanced caching strategies.
/// 
/// This class provides sophisticated AX element caching critical for cross-space window switching.
/// It implements multiple matching strategies to reliably cache AXUIElements even when windows
/// are on non-current spaces where normal AX API access is limited.
@MainActor
public final class AXElementStore {
    public static let shared = AXElementStore()

    private var cache: [CGWindowID: AXUIElement] = [:]
    private var titleOverlay: [CGWindowID: String] = [:]

    private init() {}

    public func set(_ element: AXUIElement, for windowID: CGWindowID) {
        cache[windowID] = element
    }

    public func get(for windowID: CGWindowID) -> AXUIElement? {
        return cache[windowID]
    }

    public func remove(for windowID: CGWindowID) {
        cache.removeValue(forKey: windowID)
        titleOverlay.removeValue(forKey: windowID)
    }

    public func clear() {
        cache.removeAll()
        titleOverlay.removeAll()
    }

    public var count: Int { cache.count }
    
    public var titleOverlayCount: Int { titleOverlay.count }
    
    public func getTitle(for windowID: CGWindowID) -> String? {
        return titleOverlay[windowID]
    }
    
    public func setTitle(_ title: String, for windowID: CGWindowID) {
        titleOverlay[windowID] = title
    }
    
    public func cacheElements(for windows: [WindowInfo]) async {
        guard AXIsProcessTrusted() else {
            print("[AXElementStore] No AX permissions, skipping cache")
            return
        }
        
        titleOverlay.removeAll()
        
        let windowsByProcess = Dictionary(grouping: windows) { $0.processID }
        
        print("[AXElementStore] Caching AX elements for \(windowsByProcess.count) processes")
        print("[AXElementStore] Discovered window IDs: \(windows.map { $0.id }.sorted())")
        
        for (processID, processWindows) in windowsByProcess {
            await cacheElementsForProcess(processID: processID, windows: processWindows)
        }
        
        print("[AXElementStore] Cached \(count) AX elements")
        print("[AXElementStore] Title overlay has \(titleOverlayCount) entries")
        
        let uncachedWindows = windows.filter { get(for: CGWindowID($0.id)) == nil }
        if !uncachedWindows.isEmpty {
            print("[AXElementStore] ⚠️ UNCACHED WINDOWS (\(uncachedWindows.count)):")
            for window in uncachedWindows {
                print("[AXElementStore]     Window \(window.id): '\(window.title)' - pid \(window.processID)")
            }
        }
    }
    
    private func cacheElementsForProcess(processID: pid_t, windows: [WindowInfo]) async {
        let appElement = AXUIElementCreateApplication(processID)
        
        var windowsValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            appElement,
            kAXWindowsAttribute as CFString,
            &windowsValue
        )
        
        guard result == .success, let axWindows = windowsValue as? [AXUIElement] else {
            print("[AXElementStore] ❌ Failed to get AX windows for pid \(processID)")
            print("[AXElementStore]    AXError code: \(result.rawValue)")
            await tryDirectElementCreation(for: windows, processID: processID)
            return
        }
        
        if axWindows.isEmpty && !windows.isEmpty {
            print("[AXElementStore] 🔄 Empty AX windows but have \(windows.count) discovered windows")
            print("[AXElementStore] 🔄 Attempting direct element creation (windows likely on non-current spaces)")
            await tryDirectElementCreation(for: windows, processID: processID)
            return
        }
        
        print("[AXElementStore] Got \(axWindows.count) AX windows for pid \(processID)")
        
        var titleToWindowIDs: [String: [CGWindowID]] = [:]
        for window in windows {
            if !window.title.isEmpty {
                titleToWindowIDs[window.title, default: []].append(CGWindowID(window.id))
            }
        }
        
        for (index, axWindow) in axWindows.enumerated() {
            var cached = false
            
            if let windowID = tryGetWindowID(from: axWindow) {
                set(axWindow, for: windowID)
                
                if let title = tryGetTitle(from: axWindow) {
                    setTitle(title, for: windowID)
                }
                
                cached = true
            } else if let title = tryGetTitle(from: axWindow), !title.isEmpty {
                if let matchedIDs = titleToWindowIDs[title], let firstMatch = matchedIDs.first {
                    set(axWindow, for: firstMatch)
                    setTitle(title, for: firstMatch)
                    cached = true
                    
                    if matchedIDs.count == 1 {
                        titleToWindowIDs.removeValue(forKey: title)
                    } else {
                        titleToWindowIDs[title] = Array(matchedIDs.dropFirst())
                    }
                } else {
                    let unmatchedWindows = windows.filter { window in
                        get(for: CGWindowID(window.id)) == nil
                    }
                    
                    if windows.count == axWindows.count && unmatchedWindows.count == 1 {
                        let unmatchedID = unmatchedWindows[0].id
                        set(axWindow, for: CGWindowID(unmatchedID))
                        setTitle(title, for: CGWindowID(unmatchedID))
                        cached = true
                    } else if let matchedWindow = tryMatchByBounds(axWindow: axWindow, windows: unmatchedWindows) {
                        set(axWindow, for: CGWindowID(matchedWindow.id))
                        setTitle(title, for: CGWindowID(matchedWindow.id))
                        cached = true
                    }
                }
            }
            
            if !cached {
                print("[AXElementStore] ❌ Window[\(index)] could not be cached")
            }
        }
        
        print("[AXElementStore] Process \(processID) Summary:")
        for window in windows {
            let isCached = get(for: CGWindowID(window.id)) != nil
            let hasOverlayTitle = getTitle(for: CGWindowID(window.id)) != nil
            print("[AXElementStore]   Window \(window.id): cached=\(isCached), overlayTitle=\(hasOverlayTitle), cgTitle='\(window.title)'")
        }
    }
    
    private func tryGetWindowID(from axWindow: AXUIElement) -> CGWindowID? {
        var windowIDValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, "_AXWindowID" as CFString, &windowIDValue)
        
        if result == .success, let windowID = windowIDValue as? CGWindowID {
            return windowID
        }
        return nil
    }
    
    private func tryGetTitle(from axWindow: AXUIElement) -> String? {
        var titleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
        
        if result == .success, let title = titleValue as? String, !title.isEmpty {
            return title
        }
        return nil
    }
    
    private func tryMatchByBounds(axWindow: AXUIElement, windows: [WindowInfo]) -> WindowInfo? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        
        let posResult = AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue)
        
        guard posResult == .success, sizeResult == .success,
              let positionValue = positionValue,
              let sizeValue = sizeValue,
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return nil
        }

        let position = positionValue as! AXValue
        let size = sizeValue as! AXValue
        
        var axPoint = CGPoint.zero
        var axSize = CGSize.zero
        AXValueGetValue(position, .cgPoint, &axPoint)
        AXValueGetValue(size, .cgSize, &axSize)
        let axBounds = CGRect(origin: axPoint, size: axSize)
        
        return windows.first { window in
            abs(window.bounds.origin.x - axBounds.origin.x) <= 1 &&
            abs(window.bounds.origin.y - axBounds.origin.y) <= 1 &&
            abs(window.bounds.width - axBounds.width) <= 1 &&
            abs(window.bounds.height - axBounds.height) <= 1
        }
    }
    
    private func tryDirectElementCreation(for windows: [WindowInfo], processID: pid_t) async {
        let systemWide = AXUIElementCreateSystemWide()
        
        for window in windows {
            let centerX = Float(window.bounds.midX)
            let centerY = Float(window.bounds.midY)
            
            var element: AXUIElement?
            let result = AXUIElementCopyElementAtPosition(systemWide, centerX, centerY, &element)
            
            if result == .success, let axElement = element {
                var pidValue: pid_t = 0
                let pidResult = AXUIElementGetPid(axElement, &pidValue)
                
                if pidResult == .success && pidValue == processID {
                    if let windowElement = tryGetWindowElement(from: axElement) {
                        set(windowElement, for: CGWindowID(window.id))
                        
                        if let title = tryGetTitle(from: windowElement) {
                            setTitle(title, for: CGWindowID(window.id))
                            print("[AXElementStore] ✅ Cached window \(window.id) with title '\(title)'")
                        } else {
                            print("[AXElementStore] ✅ Cached window \(window.id) (no title)")
                        }
                    }
                }
            }
        }
    }
    
    private func tryGetWindowElement(from element: AXUIElement) -> AXUIElement? {
        var roleValue: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        
        if roleResult == .success, let role = roleValue as? String {
            if role == kAXWindowRole as String {
                return element
            } else if let parentValue = tryGetParent(element),
                      CFGetTypeID(parentValue) == AXUIElementGetTypeID() {
                let parent = parentValue as! AXUIElement
                var parentRoleValue: CFTypeRef?
                if AXUIElementCopyAttributeValue(parent, kAXRoleAttribute as CFString, &parentRoleValue) == .success,
                   let parentRole = parentRoleValue as? String,
                   parentRole == kAXWindowRole as String {
                    return parent
                }
            }
        }
        return nil
    }
    
    private func tryGetParent(_ element: AXUIElement) -> CFTypeRef? {
        var parentValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parentValue)
        return parentValue
    }
}

