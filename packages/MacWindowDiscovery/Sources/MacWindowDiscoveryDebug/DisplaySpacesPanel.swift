import SwiftUI
import MacWindowDiscovery

/// Panel showing comprehensive display and space information
struct DisplaySpacesPanel: View {
    let displaySpaces: [DisplaySpaceInfo]
    let activeSpaceIDs: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display & Space Information")
                .font(.headline)
                .padding(.bottom, 4)

            if displaySpaces.isEmpty {
                Text("No display information available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(displaySpaces.enumerated()), id: \.element.displayID) { index, display in
                    DisplayInfoRow(
                        display: display,
                        isActive: activeSpaceIDs.contains(display.currentSpaceID),
                        index: index + 1
                    )
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Row showing information for a single display
struct DisplayInfoRow: View {
    let display: DisplaySpaceInfo
    let isActive: Bool
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Display \(index)")
                    .font(.system(size: 12, weight: .semibold))

                if display.isMain {
                    Text("MAIN")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(3)
                }

                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(3)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                InfoItem(label: "ID", value: String(display.displayID))
                InfoItem(label: "Current Space", value: String(display.currentSpaceID))
                InfoItem(label: "Total Spaces", value: String(display.allSpaceIDs.count))
            }

            if let uuid = display.displayUUID {
                InfoItem(label: "UUID", value: uuid)
                    .font(.system(size: 10, design: .monospaced))
            }

            HStack(spacing: 8) {
                Text("Bounds:")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(formatBounds(display.bounds))
                    .font(.system(size: 10, design: .monospaced))
            }

            if display.allSpaceIDs.count > 1 {
                HStack(spacing: 4) {
                    Text("All Spaces:")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    ForEach(display.allSpaceIDs, id: \.self) { spaceID in
                        SpaceBadge(
                            spaceID: spaceID,
                            isCurrent: spaceID == display.currentSpaceID
                        )
                    }
                }
            }
        }
        .padding(8)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(6)
    }

    private func formatBounds(_ bounds: CGRect) -> String {
        return String(format: "(%.0f, %.0f) %.0f×%.0f",
                     bounds.origin.x, bounds.origin.y,
                     bounds.size.width, bounds.size.height)
    }
}

struct InfoItem: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .medium))
        }
    }
}

struct SpaceBadge: View {
    let spaceID: Int
    let isCurrent: Bool

    var body: some View {
        Text(String(spaceID))
            .font(.system(size: 9, weight: isCurrent ? .bold : .regular))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(isCurrent ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.1))
            .cornerRadius(3)
    }
}

#Preview {
    DisplaySpacesPanel(
        displaySpaces: [
            DisplaySpaceInfo(
                displayID: 1,
                displayUUID: "12345678-1234-1234-1234-123456789012",
                currentSpaceID: 10,
                allSpaceIDs: [10, 11, 12],
                bounds: CGRect(x: 0, y: 0, width: 2560, height: 1440),
                isMain: true
            ),
            DisplaySpaceInfo(
                displayID: 2,
                displayUUID: "87654321-4321-4321-4321-210987654321",
                currentSpaceID: 20,
                allSpaceIDs: [20, 21],
                bounds: CGRect(x: 2560, y: 0, width: 1920, height: 1080),
                isMain: false
            )
        ],
        activeSpaceIDs: [10, 20]
    )
    .frame(width: 600)
}
