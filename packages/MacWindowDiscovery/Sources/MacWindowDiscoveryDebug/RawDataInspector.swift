import SwiftUI
import MacWindowDiscovery

struct RawDataInspector: View {
    let rawWindowData: RawWindowData

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Raw OS Data Inspector")
                        .font(.headline)
                    Text("Window ID: \(rawWindowData.id)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !rawWindowData.windowInfo.title.isEmpty {
                        Text(rawWindowData.windowInfo.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            .background(.bar)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Data Source Info
                    InfoSection(title: "Data Source") {
                        InfoRow(label: "Source", value: "CGWindowListCopyWindowInfo()")
                        InfoRow(label: "Type", value: "Dictionary [String: Any]")
                        InfoRow(label: "Keys Count", value: "\(rawWindowData.cgDictionary.count)")
                    }

                    Divider()

                    // Raw CGWindowList Data
                    InfoSection(title: "CGWindowList Dictionary") {
                        ForEach(rawWindowData.formattedRawData, id: \.key) { item in
                            RawDataRow(
                                key: item.key,
                                value: item.value,
                                type: item.type,
                                description: getKeyDescription(item.key)
                            )
                        }
                    }

                    Divider()

                    // Available Keys Reference
                    InfoSection(title: "CGWindowList Keys Reference") {
                        Text("Common keys available from CGWindowListCopyWindowInfo:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)

                        ForEach(CGWindowListKey.allCases, id: \.rawValue) { key in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(key.rawValue)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                Text(key.description)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 700, minHeight: 600)
    }

    private func getKeyDescription(_ key: String) -> String {
        CGWindowListKey.allCases.first { $0.rawValue == key }?.description ?? "Unknown key"
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 4) {
                content()
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)

            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)

            Spacer()
        }
    }
}

struct RawDataRow: View {
    let key: String
    let value: String
    let type: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                // Key
                Text(key)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.accentColor)
                    .textSelection(.enabled)

                Spacer()

                // Type badge
                Text(type)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(4)
            }

            // Value
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.leading, 8)
                .textSelection(.enabled)

            // Description
            Text(description)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
    }
}

#Preview {
    RawDataInspector(
        rawWindowData: RawWindowData(
            id: 123,
            windowInfo: WindowInfo(
                id: 123,
                title: "Preview Window",
                bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
                alpha: 1.0,
                isOnScreen: true,
                layer: 0,
                processID: 456,
                bundleIdentifier: "com.example.app",
                applicationName: "Example App",
                isMinimized: false,
                isHidden: false,
                isFullscreen: false,
                isFocused: false,
                isMainWindow: true,
                isTabbed: false,
                spaceIDs: [1],
                isOnAllSpaces: false,
                desktopNumber: 1,
                displayID: 1,
                role: "AXWindow",
                subrole: "AXStandardWindow",
                capturedAt: Date()
            ),
            cgDictionary: [
                "kCGWindowNumber": 123,
                "kCGWindowOwnerPID": 456,
                "kCGWindowName": "Preview Window",
                "kCGWindowAlpha": 1.0,
                "kCGWindowLayer": 0
            ]
        )
    )
}
