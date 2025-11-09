import XCTest

@testable import AltSwitch

@MainActor
final class AppearanceTests: XCTestCase {

  var settingsManager: SettingsManager!
  var configurationManager: ConfigurationManager!

  override func setUp() async throws {
    try await super.setUp()

    // Initialize services with temporary config for testing
    let tempConfigURL = URL(fileURLWithPath: "/tmp/altswitch_appearance_tests.yaml")
    settingsManager = try SettingsManager(configurationFileURL: tempConfigURL)
    configurationManager = ConfigurationManager(settingsManager: settingsManager)
  }

  override func tearDown() async throws {
    settingsManager = nil
    configurationManager = nil
    try await super.tearDown()
  }

  // MARK: - T020.1: Window Position Configuration
  func testWindowPositionConfiguration() async throws {
    // Given: Default window position
    let originalConfig = settingsManager.currentConfiguration

    // When: Window position is changed to top center
    var modifiedConfig = originalConfig.copy()
    modifiedConfig.windowPosition = .topCenter
    try await settingsManager.saveConfiguration(modifiedConfig)

    // Then: Configuration should reflect the change
    let loadedConfig = try await settingsManager.loadConfiguration()
    XCTAssertEqual(loadedConfig.windowPosition, .topCenter)

    // Cleanup: Reset to defaults
    try await settingsManager.saveConfiguration(originalConfig)
  }

  // MARK: - T020.2: Appearance Delay Configuration
  func testAppearanceDelayConfiguration() async throws {
    // Given: Default appearance delay
    let originalConfig = settingsManager.currentConfiguration

    // When: Appearance delay is changed
    var modifiedConfig = originalConfig.copy()
    modifiedConfig.appearanceDelay = 0.2
    try await settingsManager.saveConfiguration(modifiedConfig)

    // Then: Configuration should reflect the change
    let loadedConfig = try await settingsManager.loadConfiguration()
    XCTAssertEqual(loadedConfig.appearanceDelay, 0.2)

    // Cleanup: Reset to defaults
    try await settingsManager.saveConfiguration(originalConfig)
  }

  // MARK: - T020.3: Glass Effect Configuration
  func testGlassEffectConfiguration() async throws {
    // Given: Default glass effect setting
    let originalConfig = settingsManager.currentConfiguration

    // When: Glass effect is disabled
    var modifiedConfig = originalConfig.copy()
    modifiedConfig.useGlassEffect = false
    try await settingsManager.saveConfiguration(modifiedConfig)

    // Then: Configuration should reflect the change
    let loadedConfig = try await settingsManager.loadConfiguration()
    XCTAssertEqual(loadedConfig.useGlassEffect, false)

    // Cleanup: Reset to defaults
    try await settingsManager.saveConfiguration(originalConfig)
  }

  // MARK: - T020.4: Animation Configuration
  func testAnimationConfiguration() async throws {
    // Given: Default animation setting
    let originalConfig = settingsManager.currentConfiguration

    // When: Animations are disabled
    var modifiedConfig = originalConfig.copy()
    modifiedConfig.enableAnimations = false
    try await settingsManager.saveConfiguration(modifiedConfig)

    // Then: Configuration should reflect the change
    let loadedConfig = try await settingsManager.loadConfiguration()
    XCTAssertEqual(loadedConfig.enableAnimations, false)

    // Cleanup: Reset to defaults
    try await settingsManager.saveConfiguration(originalConfig)
  }

  // MARK: - T020.5: Configuration Persistence
  func testConfigurationPersistence() async throws {
    // Given: Custom configuration
    let originalConfig = settingsManager.currentConfiguration

    // When: Multiple settings are changed and saved
    var modifiedConfig = originalConfig.copy()
    modifiedConfig.windowPosition = .bottomCenter
    modifiedConfig.appearanceDelay = 0.3
    modifiedConfig.useGlassEffect = false
    modifiedConfig.enableAnimations = false
    try await settingsManager.saveConfiguration(modifiedConfig)

    // Then: All settings should persist when reloaded
    let loadedConfig = try await settingsManager.loadConfiguration()
    XCTAssertEqual(loadedConfig.windowPosition, .bottomCenter)
    XCTAssertEqual(loadedConfig.appearanceDelay, 0.3)
    XCTAssertEqual(loadedConfig.useGlassEffect, false)
    XCTAssertEqual(loadedConfig.enableAnimations, false)

    // Cleanup: Reset to defaults
    try await settingsManager.saveConfiguration(originalConfig)
  }
}
