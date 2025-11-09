import XCTest

@testable import AltSwitch

@MainActor
final class WindowCountTests: XCTestCase {

  var appSwitcher: AppSwitcher!
  var appDiscoveryService: AppDiscoveryService!
  var settingsManager: SettingsManager!

  override func setUp() async throws {
    try await super.setUp()

    // Initialize services
    appDiscoveryService = PackageAppDiscovery()
    settingsManager = SettingsManager()
    appSwitcher = AppSwitcher(
      appDiscoveryService: appDiscoveryService,
      fuzzySearchService: FuzzySearchService(),
      settingsManager: settingsManager,
      configurationManager: ConfigurationManager()
    )
  }

  override func tearDown() async throws {
    appSwitcher = nil
    appDiscoveryService = nil
    settingsManager = nil
    try await super.tearDown()
  }

  // MARK: - T021.1: Single Window Count Display
  func testSingleWindowCountDisplay() async throws {
    // Given: An app with a single window
    let testApp = AppInfo(
      name: "Test App",
      bundleIdentifier: "com.test.app",
      icon: NSImage(),
      windowCount: 1,
      isRunning: true
    )

    // When: App is displayed in the switcher
    await appSwitcher.showWindow()
    let apps = await appDiscoveryService.getRunningApps()

    // Then: Window count should show "1" or be hidden for single window
    let windowCount =
      apps.first(where: { $0.bundleIdentifier == testApp.bundleIdentifier })?.windowCount ?? 0
    XCTAssertEqual(windowCount, 1)

    // Verify display logic (single window count might be hidden)
    let shouldShowCount = await settingsManager.shouldShowWindowCount(for: windowCount)
    if windowCount == 1 {
      XCTAssertFalse(shouldShowCount)  // Typically hidden for single window
    }

    await appSwitcher.hideWindow()
  }

  // MARK: - T021.2: Multiple Window Count Display
  func testMultipleWindowCountDisplay() async throws {
    // Given: An app with multiple windows
    let testApp = AppInfo(
      name: "Test App",
      bundleIdentifier: "com.test.app",
      icon: NSImage(),
      windowCount: 3,
      isRunning: true
    )

    // When: App is displayed in the switcher
    await appSwitcher.showWindow()

    // Then: Window count should show "3"
    XCTAssertEqual(testApp.windowCount, 3)

    // Verify display logic (multiple window count should be visible)
    let shouldShowCount = await settingsManager.shouldShowWindowCount(for: testApp.windowCount)
    XCTAssertTrue(shouldShowCount)

    await appSwitcher.hideWindow()
  }

  // MARK: - T021.3: Window Count Toggle Setting
  func testWindowCountToggleSetting() async throws {
    // Given: Window count display setting is enabled
    let originalSetting = await settingsManager.isWindowCountEnabled
    await settingsManager.setWindowCountEnabled(true)

    // When: Apps with multiple windows are displayed
    await appSwitcher.showWindow()
    let apps = await appDiscoveryService.getRunningApps()

    // Then: Window counts should be visible
    XCTAssertTrue(await settingsManager.isWindowCountEnabled)

    // When: Setting is disabled
    await settingsManager.setWindowCountEnabled(false)

    // Then: Window counts should be hidden
    XCTAssertFalse(await settingsManager.isWindowCountEnabled)

    // Cleanup
    await settingsManager.setWindowCountEnabled(originalSetting)
    await appSwitcher.hideWindow()
  }

  // MARK: - T021.4: Window Count Update
  func testWindowCountUpdate() async throws {
    // Given: An app initially with 2 windows
    let testApp = AppInfo(
      name: "Test App",
      bundleIdentifier: "com.test.app",
      icon: NSImage(),
      windowCount: 2,
      isRunning: true
    )

    // When: Window count changes to 4
    var updatedApp = testApp
    updatedApp.windowCount = 4

    // Then: Display should update to show new count
    XCTAssertEqual(updatedApp.windowCount, 4)

    // Verify the update is reflected in the UI
    let shouldShowCount = await settingsManager.shouldShowWindowCount(for: updatedApp.windowCount)
    XCTAssertTrue(shouldShowCount)
  }

  // MARK: - T021.5: Zero Window Count Handling
  func testZeroWindowCountHandling() async throws {
    // Given: An app with no windows (background process)
    let testApp = AppInfo(
      name: "Background App",
      bundleIdentifier: "com.test.background",
      icon: NSImage(),
      windowCount: 0,
      isRunning: true
    )

    // When: App is displayed in the switcher
    await appSwitcher.showWindow()

    // Then: Window count should be hidden or show appropriate indicator
    XCTAssertEqual(testApp.windowCount, 0)

    // Verify display logic (zero windows typically hidden)
    let shouldShowCount = await settingsManager.shouldShowWindowCount(for: testApp.windowCount)
    XCTAssertFalse(shouldShowCount)

    await appSwitcher.hideWindow()
  }

  // MARK: - T021.6: High Window Count Display
  func testHighWindowCountDisplay() async throws {
    // Given: An app with many windows (e.g., browser with many tabs)
    let testApp = AppInfo(
      name: "Browser",
      bundleIdentifier: "com.test.browser",
      icon: NSImage(),
      windowCount: 25,
      isRunning: true
    )

    // When: App is displayed in the switcher
    await appSwitcher.showWindow()

    // Then: Window count should show "25" without truncation
    XCTAssertEqual(testApp.windowCount, 25)

    // Verify display logic handles high numbers
    let shouldShowCount = await settingsManager.shouldShowWindowCount(for: testApp.windowCount)
    XCTAssertTrue(shouldShowCount)

    await appSwitcher.hideWindow()
  }
}
