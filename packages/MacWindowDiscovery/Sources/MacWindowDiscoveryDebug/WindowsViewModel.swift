import Foundation
import SwiftUI
import MacWindowDiscovery

@MainActor
class WindowsViewModel: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var rawData: [RawWindowData] = []
    @Published var displaySpaces: [DisplaySpaceInfo] = []
    @Published var activeSpaceIDs: [Int] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var filterOptions: FilterOptions = FilterOptions()
    @Published var selectedWindowForInspection: RawWindowData?

    var windowNodes: [WindowNode] {
        let nodes = WindowNodeConverter.convert(windows: windows)
        if searchText.isEmpty {
            return nodes
        }
        return nodes.compactMap { $0.filtered(by: searchText) }
    }

    var statusText: String {
        if isLoading {
            return "Loading..."
        } else if let error = error {
            return "Error: \(error)"
        } else {
            return "\(windows.count) windows"
        }
    }

    func refresh() async {
        isLoading = true
        error = nil

        do {
            // Use filter options to create discovery options
            let options = filterOptions.toWindowDiscoveryOptions()

            // Use debug discovery to get both WindowInfo and raw data
            rawData = try await DebugWindowDiscovery.discoverWithRawData(options: options)
            windows = rawData.map { $0.windowInfo }

            // Get comprehensive display and space information
            displaySpaces = SpacesAPI.getAllDisplaySpaces()
            activeSpaceIDs = SpacesAPI.activeSpaceIDs()

            error = nil
        } catch {
            self.error = error.localizedDescription
            windows = []
            rawData = []
            displaySpaces = []
            activeSpaceIDs = []
        }

        isLoading = false
    }

    func showRawDataInspector(for windowInfo: WindowInfo) {
        selectedWindowForInspection = rawData.first { $0.windowInfo.id == windowInfo.id }
    }

    func applyPreset(_ preset: FilterPreset) {
        filterOptions.applyPreset(preset)
    }

    func toggleFilter() {
        // Mark as custom when manually toggling filters
        if filterOptions.preset != .custom {
            filterOptions.preset = .custom
        }
    }
}
