import Foundation
import CoreGraphics
import MacWindowDiscovery

/// Debug-specific window discovery that captures raw OS data alongside WindowInfo
struct DebugWindowDiscovery {

    /// Discover windows and capture raw CGWindowList data
    static func discoverWithRawData(options: WindowDiscoveryOptions) async throws -> [RawWindowData] {
        // Create providers
        let cgProvider = CGWindowProvider()
        let engine = WindowDiscoveryEngine()

        // Get raw CG window list
        let cgOption: CGWindowListOption = options.includeInactiveSpaces ? .optionAll : .optionOnScreenOnly
        let rawWindows = try cgProvider.captureWindowList(option: cgOption)

        // Get processed WindowInfo
        let windowInfos = try await engine.discoverWindows(options: options)

        // Create lookup by window ID
        let windowInfoLookup = Dictionary(uniqueKeysWithValues: windowInfos.map { ($0.id, $0) })

        // Match raw data with processed data
        let rawData = rawWindows.compactMap { cgDict -> RawWindowData? in
            guard let windowID = cgDict[kCGWindowNumber as String] as? CGWindowID,
                  let windowInfo = windowInfoLookup[windowID] else {
                return nil
            }

            return RawWindowData(
                id: windowID,
                windowInfo: windowInfo,
                cgDictionary: cgDict
            )
        }

        return rawData
    }
}
