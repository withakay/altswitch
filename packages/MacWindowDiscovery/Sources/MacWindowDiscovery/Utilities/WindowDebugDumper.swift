import Foundation
import CoreGraphics

/// Utility for generating debug information about discovered windows
@MainActor
public final class WindowDebugDumper {
    
    public static let shared = WindowDebugDumper()
    
    private init() {}
    
    public func generateDebugReport(windows: [WindowInfo], includeSpaceInfo: Bool = true) -> String {
        var debugOutput = """
        # Window Debug Information
        Generated: \(Date())
        Package Version: MacWindowDiscovery
        Total Windows: \(windows.count)
        
        """
        
        struct AppGroupKey: Hashable {
            let processID: pid_t
            let appName: String
            let bundleID: String
        }
        
        let groupedByApp = Dictionary(grouping: windows) { window in
            AppGroupKey(
                processID: window.processID,
                appName: window.applicationName ?? "Unknown",
                bundleID: window.bundleIdentifier ?? "unknown"
            )
        }
        
        for (key, appWindows) in groupedByApp.sorted(by: { $0.key.processID < $1.key.processID }) {
            let processID = key.processID
            let appName = key.appName
            let bundleID = key.bundleID
            
            debugOutput += """
            
            ## \(appName) (\(bundleID))
            Process ID: \(processID)
            Windows: \(appWindows.count)
            
            """
            
            for window in appWindows {
                debugOutput += """
                
                ### Window \(window.id)
                - Title: "\(window.title)"
                - Bounds: \(window.bounds)
                - Alpha: \(window.alpha)
                - Layer: \(window.layer)
                - On Screen: \(window.isOnScreen)
                - Hidden: \(window.isHidden)
                - Minimized: \(window.isMinimized)
                - Fullscreen: \(window.isFullscreen)
                - Focused: \(window.isFocused)
                - Role: \(window.role ?? "nil")
                - Subrole: \(window.subrole ?? "nil")
                - Captured At: \(window.capturedAt)
                
                """
                
                if includeSpaceInfo {
                    debugOutput += """
                    - Space IDs: \(window.spaceIDs)
                    - On All Spaces: \(window.isOnAllSpaces)
                    - Desktop Number: \(window.desktopNumber.map(String.init) ?? "nil")
                    
                    """
                }
            }
        }
        
        return debugOutput
    }
    
    public func saveDebugReport(windows: [WindowInfo], includeSpaceInfo: Bool = true) throws -> URL {
        let report = generateDebugReport(windows: windows, includeSpaceInfo: includeSpaceInfo)
        
        let fileManager = FileManager.default
        let configDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("altswitch")
            .appendingPathComponent("debug")
        
        try fileManager.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let debugFile = configDir.appendingPathComponent("window-debug-\(timestamp).md")
        try report.write(to: debugFile, atomically: true, encoding: .utf8)
        
        return debugFile
    }
}