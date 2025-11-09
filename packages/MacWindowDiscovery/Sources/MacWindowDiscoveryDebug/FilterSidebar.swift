import SwiftUI

struct FilterSidebar: View {
    @ObservedObject var viewModel: WindowsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PresetSection(viewModel: viewModel)
                Divider()
                SizeFiltersSection(viewModel: viewModel, binding: binding)
                Divider()
                VisualFiltersSection(viewModel: viewModel, binding: binding)
                Divider()
                StateFiltersSection(viewModel: viewModel, binding: binding)
                Divider()
                SpaceFiltersSection(viewModel: viewModel, binding: binding)
                Divider()
                RequirementsSection(viewModel: viewModel, binding: binding)
                Divider()
                ApplicationFiltersSection(viewModel: viewModel, binding: binding)
                Divider()
                PerformanceSection(viewModel: viewModel, binding: binding)
                Spacer()
            }
            .padding()
        }
        .frame(width: 240)
        .background(.background.opacity(0.5))
    }

    // Helper to create bindings that trigger refresh and mark as custom
    private func binding<T>(for keyPath: WritableKeyPath<FilterOptions, T>) -> Binding<T> {
        Binding(
            get: {
                viewModel.filterOptions[keyPath: keyPath]
            },
            set: { newValue in
                viewModel.filterOptions[keyPath: keyPath] = newValue
                viewModel.toggleFilter()
                Task {
                    await viewModel.refresh()
                }
            }
        )
    }
}

// MARK: - Section Views

struct PresetSection: View {
    @ObservedObject var viewModel: WindowsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Presets")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                ForEach(FilterPreset.allCases.filter { $0 != .custom }) { preset in
                    PresetButton(preset: preset, viewModel: viewModel)
                }
            }
        }
    }
}

struct PresetButton: View {
    let preset: FilterPreset
    @ObservedObject var viewModel: WindowsViewModel

    var body: some View {
        Button(action: {
            viewModel.applyPreset(preset)
            Task {
                await viewModel.refresh()
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.rawValue)
                        .font(.system(size: 12, weight: viewModel.filterOptions.preset == preset ? .semibold : .regular))
                    Text(preset.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.filterOptions.preset == preset {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            viewModel.filterOptions.preset == preset ?
            Color.accentColor.opacity(0.1) : Color.clear
        )
        .cornerRadius(6)
    }
}

struct SizeFiltersSection: View {
    @ObservedObject var viewModel: WindowsViewModel
    let binding: (WritableKeyPath<FilterOptions, Bool>) -> Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Size Filters")
                .font(.headline)
                .foregroundStyle(.secondary)

            FilterToggle(
                title: "Minimum Size",
                subtitle: "100x50 pixels",
                isOn: binding(\.useMinimumSize)
            )
        }
    }
}

struct VisualFiltersSection: View {
    @ObservedObject var viewModel: WindowsViewModel
    let binding: (WritableKeyPath<FilterOptions, Bool>) -> Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Visual Filters")
                .font(.headline)
                .foregroundStyle(.secondary)

            FilterToggle(
                title: "Normal Layer Only",
                subtitle: "Layer 0 windows",
                isOn: binding(\.normalLayerOnly)
            )

            FilterToggle(
                title: "Minimum Alpha",
                subtitle: "90% opacity",
                isOn: binding(\.useMinimumAlpha)
            )
        }
    }
}

struct StateFiltersSection: View {
    @ObservedObject var viewModel: WindowsViewModel
    let binding: (WritableKeyPath<FilterOptions, Bool>) -> Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("State Filters")
                .font(.headline)
                .foregroundStyle(.secondary)

            FilterToggle(
                title: "Include Hidden",
                subtitle: "Show hidden windows",
                isOn: binding(\.includeHidden)
            )

            FilterToggle(
                title: "Include Minimized",
                subtitle: "Show minimized windows",
                isOn: binding(\.includeMinimized)
            )
        }
    }
}

struct SpaceFiltersSection: View {
    @ObservedObject var viewModel: WindowsViewModel
    let binding: (WritableKeyPath<FilterOptions, Bool>) -> Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Space Filters")
                .font(.headline)
                .foregroundStyle(.secondary)

            FilterToggle(
                title: "Include Inactive Spaces",
                subtitle: "All spaces, not just active",
                isOn: binding(\.includeInactiveSpaces)
            )
        }
    }
}

struct RequirementsSection: View {
    @ObservedObject var viewModel: WindowsViewModel
    let binding: (WritableKeyPath<FilterOptions, Bool>) -> Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Requirements")
                .font(.headline)
                .foregroundStyle(.secondary)

            FilterToggle(
                title: "Require Title",
                subtitle: "Windows must have titles",
                isOn: binding(\.requireTitle)
            )

            FilterToggle(
                title: "Require Proper Subrole",
                subtitle: "AXStandardWindow/AXDialog",
                isOn: binding(\.requireProperSubrole)
            )
        }
    }
}

struct ApplicationFiltersSection: View {
    @ObservedObject var viewModel: WindowsViewModel
    let binding: (WritableKeyPath<FilterOptions, Bool>) -> Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Application Filters")
                .font(.headline)
                .foregroundStyle(.secondary)

            FilterToggle(
                title: "Exclude System Processes",
                subtitle: "Dock, Control Center, etc.",
                isOn: binding(\.excludeSystemProcesses)
            )
        }
    }
}

struct PerformanceSection: View {
    @ObservedObject var viewModel: WindowsViewModel
    let binding: (WritableKeyPath<FilterOptions, Bool>) -> Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance")
                .font(.headline)
                .foregroundStyle(.secondary)

            FilterToggle(
                title: "Use Accessibility API",
                subtitle: "Slower but more accurate",
                isOn: binding(\.useAccessibilityAPI)
            )
        }
    }
}

struct FilterToggle: View {
    let title: String
    let subtitle: String
    let isOn: Binding<Bool>

    var body: some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
    }
}

#Preview {
    FilterSidebar(viewModel: WindowsViewModel())
}
