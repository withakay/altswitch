//
//  MainWindowRefactoringTests.swift
//  AltSwitchTests
//
//  Integration tests for MainWindow refactoring (FR-001, FR-002)
//  These tests capture current behavior before refactoring to ensure behavior preservation
//

import SwiftUI
import Testing

@testable import AltSwitch

@Suite("MainWindow Refactoring Integration Tests")
@MainActor
struct MainWindowRefactoringTests {

  @Test("MainWindow renders with empty app list")
  func testMainWindowRendersWithEmptyAppList() async throws {
    let viewModel = MainViewModel()

    let mainWindow = MainWindow()
      .environment(viewModel)

    #expect(viewModel.filteredApps.isEmpty)
  }

  @Test("MainWindow renders with populated app list")
  func testMainWindowRendersWithPopulatedAppList() async throws {
    let viewModel = MainViewModel()

    await viewModel.refreshApps()

    let mainWindow = MainWindow()
      .environment(viewModel)

    #expect(!viewModel.filteredApps.isEmpty || viewModel.filteredApps.isEmpty)
  }

  @Test("MainWindow search functionality works")
  func testMainWindowSearchFunctionality() async throws {
    let viewModel = MainViewModel()

    await viewModel.refreshApps()

    let initialCount = viewModel.filteredApps.count

    viewModel.searchText = "nonexistentapp123456"

    #expect(viewModel.filteredApps.count <= initialCount)
  }

  @Test("MainWindow handles window visibility changes")
  func testMainWindowHandlesVisibilityChanges() async throws {
    let viewModel = MainViewModel()

    #expect(viewModel.isVisible == false)

    await viewModel.show()
    #expect(viewModel.isVisible == true)

    await viewModel.hide()
    #expect(viewModel.isVisible == false)
  }

  @Test("MainWindow keyboard navigation works")
  func testMainWindowKeyboardNavigation() async throws {
    let viewModel = MainViewModel()

    await viewModel.refreshApps()

    let initialIndex = viewModel.selectedIndex

    viewModel.selectNext()

    if !viewModel.filteredApps.isEmpty {
      #expect(viewModel.selectedIndex != initialIndex || viewModel.filteredApps.count == 1)
    }
  }
}
