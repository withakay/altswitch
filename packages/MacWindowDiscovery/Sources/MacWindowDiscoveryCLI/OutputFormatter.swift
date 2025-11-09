import Foundation
import ArgumentParser
import MacWindowDiscovery

enum OutputFormat: String, ExpressibleByArgument {
    case table
    case json
    case compact
}

struct OutputFormatter {
    let format: OutputFormat

    func format(windows: [WindowInfo]) {
        switch format {
        case .table:
            formatTable(windows)
        case .json:
            formatJSON(windows)
        case .compact:
            formatCompact(windows)
        }
    }

    private func formatTable(_ windows: [WindowInfo]) {
        guard !windows.isEmpty else {
            print("No windows found")
            return
        }

        // Header
        print(String(repeating: "=", count: 120))
        print(String(format: "%-6s %-20s %-30s %-15s %s",
                    "ID", "App", "Title", "Size", "State"))
        print(String(repeating: "=", count: 120))

        // Rows
        for window in windows {
            let appName = window.applicationName ?? window.bundleIdentifier ?? "Unknown"
            let title = truncate(window.title, to: 30)
            let size = String(format: "%.0fx%.0f", window.bounds.width, window.bounds.height)
            let state = buildState(window)

            print(String(format: "%-6d %-20s %-30s %-15s %s",
                        window.id,
                        truncate(appName, to: 20),
                        title,
                        size,
                        state))
        }

        print(String(repeating: "=", count: 120))
        print("Total: \(windows.count) windows")
    }

    private func formatJSON(_ windows: [WindowInfo]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(windows)
            if let json = String(data: data, encoding: .utf8) {
                print(json)
            }
        } catch {
            print("Error encoding JSON: \(error)")
        }
    }

    private func formatCompact(_ windows: [WindowInfo]) {
        guard !windows.isEmpty else {
            print("No windows found")
            return
        }

        for window in windows {
            let appName = window.applicationName ?? window.bundleIdentifier ?? "Unknown"
            let state = buildState(window)
            print("[\(window.id)] \(appName): \(window.title) \(state)")
        }

        print("\nTotal: \(windows.count) windows")
    }

    private func buildState(_ window: WindowInfo) -> String {
        var parts: [String] = []

        if window.isMinimized { parts.append("MIN") }
        if window.isHidden { parts.append("HID") }
        if window.isFullscreen { parts.append("FULL") }
        if window.isFocused { parts.append("FOCUS") }
        if !window.isOnScreen { parts.append("OFFSCREEN") }

        return parts.isEmpty ? "" : "[\(parts.joined(separator: ","))]"
    }

    private func truncate(_ string: String, to length: Int) -> String {
        if string.count <= length {
            return string.padding(toLength: length, withPad: " ", startingAt: 0)
        }
        let truncated = String(string.prefix(length - 3))
        return truncated + "..."
    }
}
