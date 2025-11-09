import Foundation

@MainActor
extension MainViewModel {
  func selectPrevious() {
    if !filteredApps.isEmpty {
      selectedIndex = max(0, selectedIndex - 1)
    }
  }

  func selectNext() {
    if !filteredApps.isEmpty {
      selectedIndex = min(filteredApps.count - 1, selectedIndex + 1)
    }
  }

  func cycleForward() {
    guard !filteredApps.isEmpty else { return }
    selectedIndex = (selectedIndex + 1) % filteredApps.count
  }

  func cycleBackward() {
    guard !filteredApps.isEmpty else { return }
    selectedIndex = (selectedIndex - 1 + filteredApps.count) % filteredApps.count
  }

  func updateFilteredApps() {
    print("🔍 [updateFilteredApps] START - allApps.count: \(allApps.count), searchText: '\(searchText)'")
    debounceTask?.cancel()

    let apps = allApps

    guard !searchText.isEmpty else {
      print("📋 [updateFilteredApps] Empty search - showing all apps")
      let sortedApps = activationTracker.sorted(apps)
      filteredApps = sortedApps.map {
        SearchResult(app: $0, score: 1.0, matchedFields: [.name])
      }
      print("✅ [updateFilteredApps] Set filteredApps to \(filteredApps.count) apps")
      if selectedIndex >= filteredApps.count {
        selectedIndex = max(0, filteredApps.count - 1)
      }
      return
    }

    let query = searchText
    let searchService = fuzzySearch

    print("⏱️ [updateFilteredApps] Debouncing search for query: '\(query)'")
    debounceTask = Task { @MainActor [weak self] in
      guard let self else { return }
      let appsCopy = apps
      let queryCopy = query
      let searchService = self.fuzzySearch

      Task.detached(priority: .userInitiated) { [searchService] in
        do {
          try await Task.sleep(for: .milliseconds(100))
        } catch {
          print("⚠️ [updateFilteredApps] Debounce cancelled")
          return
        }

        guard !Task.isCancelled else {
          print("⚠️ [updateFilteredApps] Task cancelled")
          return
        }
        print("🔎 [updateFilteredApps] Searching for '\(queryCopy)' in \(appsCopy.count) apps")
        let results = await searchService.search(queryCopy, in: appsCopy)

        guard !Task.isCancelled else {
          print("⚠️ [updateFilteredApps] Task cancelled after search")
          return
        }
        await MainActor.run { [weak self] in
          guard let self else { return }
          print("✅ [updateFilteredApps] Setting filteredApps to \(results.count) search results")
          self.filteredApps = results
          if self.selectedIndex >= self.filteredApps.count {
            self.selectedIndex = 0
          }
        }
      }
    }
  }
}
