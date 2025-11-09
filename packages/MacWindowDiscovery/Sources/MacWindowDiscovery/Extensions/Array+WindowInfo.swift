import Foundation

extension Array where Element == WindowInfo {
    /// Filter to only standard windows (exclude utility panels)
    public var standardWindows: [WindowInfo] {
        filter { $0.isStandardWindow }
    }

    /// Filter to only visible windows (not hidden/minimized)
    public var visibleWindows: [WindowInfo] {
        filter { !$0.isHidden && !$0.isMinimized }
    }

    /// Filter to windows on the active Space
    public func onActiveSpace() -> [WindowInfo] {
        let activeSpaceID = SpacesAPI.activeSpaceID()
        guard activeSpaceID != 0 else {
            return self  // Can't determine, return all
        }

        return filter { $0.spaceIDs.contains(activeSpaceID) }
    }

    /// Group windows by application
    public func groupedByApplication() -> [pid_t: [WindowInfo]] {
        Dictionary(grouping: self, by: \.processID)
    }

    /// Sort windows by title
    public func sortedByTitle() -> [WindowInfo] {
        sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    /// Sort windows by application name
    public func sortedByApp() -> [WindowInfo] {
        sorted {
            let name0 = $0.applicationName ?? $0.bundleIdentifier ?? ""
            let name1 = $1.applicationName ?? $1.bundleIdentifier ?? ""
            return name0.localizedCaseInsensitiveCompare(name1) == .orderedAscending
        }
    }
}
