//
//  FiltersTab.swift
//  AltSwitch
//
//  Application and window filtering settings
//

import SwiftUI

struct FiltersTab: View {
  // MARK: - Environment & State
  @Environment(MainViewModel.self) private var mainViewModel
  @State private var applicationNameExcludeList: Set<String> = []
  @State private var untitledWindowExcludeList: Set<String> = []
  @State private var newAppName = ""
  @State private var newUntitledAppName = ""
  
  // MARK: - Body
  var body: some View {
    Form {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("Exclude all windows from specific applications")
            .font(.headline)
          
          Text("Applications listed here will have ALL their windows hidden from AltSwitch, regardless of window title.")
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          
          HStack {
            TextField("Application name (e.g., Slack)", text: $newAppName)
              .textFieldStyle(.roundedBorder)
              .onSubmit {
                addToExcludeList()
              }
            
            Button("Add") {
              addToExcludeList()
            }
            .disabled(newAppName.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          
          if !applicationNameExcludeList.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              ForEach(Array(applicationNameExcludeList).sorted(), id: \.self) { appName in
                HStack {
                  Image(systemName: "app.fill")
                    .foregroundColor(.secondary)
                  Text(appName)
                  Spacer()
                  Button {
                    removeFromExcludeList(appName)
                  } label: {
                    Image(systemName: "trash")
                      .foregroundColor(.red)
                  }
                  .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
              }
            }
            .padding(.top, 4)
          } else {
            Text("No applications excluded")
              .font(.caption)
              .foregroundColor(.secondary)
              .italic()
          }
        }
      } header: {
        Label("Application Exclude List", systemImage: "app.badge.fill")
      }
      
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text("Exclude untitled windows from specific applications")
            .font(.headline)
          
          Text("Applications listed here will only hide windows without titles. Titled windows will still appear in AltSwitch. Useful for apps like Terminal with many background tabs.")
            .font(.caption)
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
          
          HStack {
            TextField("Application name (e.g., Terminal)", text: $newUntitledAppName)
              .textFieldStyle(.roundedBorder)
              .onSubmit {
                addToUntitledExcludeList()
              }
            
            Button("Add") {
              addToUntitledExcludeList()
            }
            .disabled(newUntitledAppName.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          
          if !untitledWindowExcludeList.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              ForEach(Array(untitledWindowExcludeList).sorted(), id: \.self) { appName in
                HStack {
                  Image(systemName: "doc.text")
                    .foregroundColor(.secondary)
                  Text(appName)
                  Spacer()
                  Button {
                    removeFromUntitledExcludeList(appName)
                  } label: {
                    Image(systemName: "trash")
                      .foregroundColor(.red)
                  }
                  .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
              }
            }
            .padding(.top, 4)
          } else {
            Text("No applications excluded")
              .font(.caption)
              .foregroundColor(.secondary)
              .italic()
          }
        }
      } header: {
        Label("Untitled Window Exclude List", systemImage: "doc.badge.fill")
      }
    }
    .padding()
    .formStyle(.grouped)
    .onAppear {
      loadCurrentSettings()
    }
    .onChange(of: mainViewModel.configuration.applicationNameExcludeList) { newList in
      applicationNameExcludeList = newList
    }
    .onChange(of: mainViewModel.configuration.untitledWindowExcludeList) { newList in
      untitledWindowExcludeList = newList
    }
  }
  
  // MARK: - Private Methods
  
  private func loadCurrentSettings() {
    applicationNameExcludeList = mainViewModel.configuration.applicationNameExcludeList
    untitledWindowExcludeList = mainViewModel.configuration.untitledWindowExcludeList
  }
  
  private func addToExcludeList() {
    let trimmed = newAppName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    
    applicationNameExcludeList.insert(trimmed)
    newAppName = ""
    saveSettings()
  }
  
  private func removeFromExcludeList(_ appName: String) {
    applicationNameExcludeList.remove(appName)
    saveSettings()
  }
  
  private func addToUntitledExcludeList() {
    let trimmed = newUntitledAppName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    
    untitledWindowExcludeList.insert(trimmed)
    newUntitledAppName = ""
    saveSettings()
  }
  
  private func removeFromUntitledExcludeList(_ appName: String) {
    untitledWindowExcludeList.remove(appName)
    saveSettings()
  }
  
  private func saveSettings() {
    Task {
      let config = mainViewModel.configuration.copy()
      config.applicationNameExcludeList = applicationNameExcludeList
      config.untitledWindowExcludeList = untitledWindowExcludeList
      
      try await mainViewModel.settingsManager.saveConfiguration(config)
    }
  }
}

#Preview {
  FiltersTabPreviewContainer()
}

// Helper container for previews
private struct FiltersTabPreviewContainer: View {
  var body: some View {
    if let mockSettings = try? SettingsManager() {
      let mockSettingsVM = SettingsViewModel.create(
        with: mockSettings,
        hotkeyManager: KeyboardShortcutsHotkeyManager()
      )
      let mockMainVM = MainViewModel(
        appDiscovery: PackageAppDiscovery(),
        appSwitcher: AppSwitcher.shared,
        fuzzySearch: FuzzySearchService(),
        hotkeyManager: KeyboardShortcutsHotkeyManager(),
        settingsManager: mockSettings
      )
      
      FiltersTab()
        .environment(mockSettingsVM)
        .environment(mockMainVM)
        .frame(width: 600, height: 400)
    } else {
      Text("Preview unavailable")
    }
  }
}
