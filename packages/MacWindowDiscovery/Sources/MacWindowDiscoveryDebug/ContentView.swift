import SwiftUI
import MacWindowDiscovery

struct ContentView: View {
    @StateObject private var viewModel = WindowsViewModel()
    @State private var showSidebar: Bool = true

    var body: some View {
        HSplitView {
            // Sidebar
            if showSidebar {
                FilterSidebar(viewModel: viewModel)
            }

            // Main content
            mainContent
        }
        .frame(minWidth: 1000, minHeight: 600)
        .task {
            await viewModel.refresh()
        }
    }

    var mainContent: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Toggle sidebar button
                Button(action: {
                    withAnimation {
                        showSidebar.toggle()
                    }
                }) {
                    Label("Filters", systemImage: "sidebar.left")
                }
                .help("Toggle filter sidebar")

                Text("MacWindowDiscovery Debug")
                    .font(.headline)
                    .padding(.leading, 8)

                Spacer()

                // Current preset indicator
                Text("Preset: \(viewModel.filterOptions.preset.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)

                Text(viewModel.statusText)
                    .foregroundStyle(.secondary)
                    .font(.caption)

                Button(action: {
                    Task {
                        await viewModel.refresh()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
            .padding()
            .background(.bar)

            Divider()

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search windows and properties...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.bar)

            Divider()

            // Display and Space Information Panel
            if !viewModel.displaySpaces.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    DisplaySpacesPanel(
                        displaySpaces: viewModel.displaySpaces,
                        activeSpaceIDs: viewModel.activeSpaceIDs
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.primary.opacity(0.03))

                Divider()
            }

            // Tree view
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading windows...")
                Spacer()
            } else if viewModel.windows.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "macwindow")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No windows found")
                        .font(.title2)
                    Text("Click Refresh to discover windows")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.windowNodes) { node in
                            WindowNodeRow(
                                node: node,
                                level: 0,
                                searchTerm: viewModel.searchText,
                                viewModel: viewModel
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(item: $viewModel.selectedWindowForInspection) { rawData in
            RawDataInspector(rawWindowData: rawData)
        }
    }
}

struct WindowNodeRow: View {
    let node: WindowNode
    let level: Int
    let searchTerm: String
    @ObservedObject var viewModel: WindowsViewModel

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Current node
            HStack(spacing: 4) {
                // Indentation
                if level > 0 {
                    Color.clear
                        .frame(width: CGFloat(level) * 20)
                }

                // Disclosure indicator
                if node.children != nil {
                    Button(action: {
                        withAnimation(.snappy(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 12)
                }

                // Content
                if let value = node.value {
                    Text(node.label)
                        .foregroundStyle(.secondary)
                    Text(":")
                        .foregroundStyle(.secondary)
                    Text(value)
                        .foregroundStyle(.primary)
                        .fontWeight(node.isSearchMatch ? .semibold : .regular)
                } else {
                    Text(node.label)
                        .fontWeight(level == 0 ? .semibold : (node.isSearchMatch ? .semibold : .regular))
                        .foregroundStyle(level == 0 ? .primary : .secondary)
                }

                Spacer()

                // Inspector button (only for root-level nodes with WindowInfo)
                if level == 0, let windowInfo = node.windowInfo {
                    Button(action: {
                        viewModel.showRawDataInspector(for: windowInfo)
                    }) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .help("View raw OS data for this window")
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(node.isSearchMatch ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.children != nil {
                    withAnimation(.snappy(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Children
            if isExpanded, let children = node.children {
                ForEach(children) { child in
                    WindowNodeRow(
                        node: child,
                        level: level + 1,
                        searchTerm: searchTerm,
                        viewModel: viewModel
                    )
                }
            }
        }
        .onAppear {
            // Auto-expand if this node or its children match search
            if !searchTerm.isEmpty && node.matches(searchTerm: searchTerm) {
                isExpanded = true
            }
        }
        .onChange(of: searchTerm) { newValue in
            if !newValue.isEmpty && node.matches(searchTerm: newValue) {
                isExpanded = true
            } else if newValue.isEmpty {
                isExpanded = false
            }
        }
    }
}

#Preview {
    ContentView()
}
