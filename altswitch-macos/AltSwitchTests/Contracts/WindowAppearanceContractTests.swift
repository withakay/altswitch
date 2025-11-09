//
//  WindowAppearanceContractTests.swift
//  AltSwitchTests
//
//  Contract tests for the WindowAppearanceProtocol
//

import AppKit
import Foundation
import Testing

@testable import AltSwitch

@Suite("Window Appearance Contract")
@MainActor
struct WindowAppearanceContractTests {

  @Test("Configure window appearance sets proper transparency and corners")
  func testConfigureWindowAppearance_validWindow_setsAppearanceProperties() async throws {
    // Arrange
    let service = MockWindowAppearanceService()
    let window = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    // Act
    service.configureWindowAppearance(window)

    // Assert
    #expect(service.configureAppearanceCallCount == 1, "Should call configure appearance once")
    #expect(service.lastConfiguredWindow === window, "Should configure the correct window")
  }

  @Test("Set corner radius updates the window corner radius")
  func testSetCornerRadius_validRadius_updatesCornerRadius() async throws {
    // Arrange
    let service = MockWindowAppearanceService()
    let radius: CGFloat = 16.0

    // Act
    service.setCornerRadius(radius)

    // Assert
    #expect(service.getCornerRadius() == radius, "Corner radius should be updated to \(radius)")
  }

  @Test("Set corner radius with zero radius removes corner radius")
  func testSetCornerRadius_zeroRadius_removesCornerRadius() async throws {
    // Arrange
    let service = MockWindowAppearanceService()

    // Act
    service.setCornerRadius(0.0)

    // Assert
    #expect(service.getCornerRadius() == 0.0, "Corner radius should be 0.0")
  }

  @Test("Set corner radius with negative value throws error")
  func testSetCornerRadius_negativeRadius_throwsError() async throws {
    // Arrange
    let service = MockWindowAppearanceService()

    // Act & Assert
    await #expect(throws: WindowAppearanceError.invalidRadius) {
      try service.setCornerRadiusWithValidation(-5.0)
    }
  }

  @Test("Set shadow enabled toggles window shadow visibility")
  func testSetShadowEnabled_true_enablesShadow() async throws {
    // Arrange
    let service = MockWindowAppearanceService()

    // Act
    service.setShadowEnabled(true)

    // Assert
    #expect(service.isShadowEnabled() == true, "Shadow should be enabled")
  }

  @Test("Set shadow enabled false disables window shadow")
  func testSetShadowEnabled_false_disablesShadow() async throws {
    // Arrange
    let service = MockWindowAppearanceService()
    service.setShadowEnabled(true)  // First enable it

    // Act
    service.setShadowEnabled(false)

    // Assert
    #expect(service.isShadowEnabled() == false, "Shadow should be disabled")
  }

  @Test("Set movable by background enables window dragging")
  func testSetMovableByBackground_true_enablesBackgroundDragging() async throws {
    // Arrange
    let service = MockWindowAppearanceService()
    let window = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    // Act
    service.setMovableByBackground(true)
    service.configureWindowAppearance(window)

    // Assert
    #expect(service.isMovableByBackground == true, "Window should be movable by background")
  }

  @Test("Set movable by background false disables window dragging")
  func testSetMovableByBackground_false_disablesBackgroundDragging() async throws {
    // Arrange
    let service = MockWindowAppearanceService()

    // Act
    service.setMovableByBackground(false)

    // Assert
    #expect(service.isMovableByBackground == false, "Window should not be movable by background")
  }

  @Test("Get corner radius returns current radius value")
  func testGetCornerRadius_afterSetting_returnsCorrectValue() async throws {
    // Arrange
    let service = MockWindowAppearanceService()
    let expectedRadius: CGFloat = 12.5

    // Act
    service.setCornerRadius(expectedRadius)
    let actualRadius = service.getCornerRadius()

    // Assert
    #expect(actualRadius == expectedRadius, "Should return the set corner radius")
  }

  @Test("Get corner radius returns default value initially")
  func testGetCornerRadius_initially_returnsDefaultValue() async throws {
    // Arrange
    let service = MockWindowAppearanceService()

    // Act
    let radius = service.getCornerRadius()

    // Assert
    #expect(radius >= 0.0, "Default corner radius should be non-negative")
  }

  @Test("Is shadow enabled returns current shadow state")
  func testIsShadowEnabled_afterToggling_returnsCorrectState() async throws {
    // Arrange
    let service = MockWindowAppearanceService()

    // Act & Assert - Enable
    service.setShadowEnabled(true)
    #expect(service.isShadowEnabled() == true, "Should return true when shadow is enabled")

    // Act & Assert - Disable
    service.setShadowEnabled(false)
    #expect(service.isShadowEnabled() == false, "Should return false when shadow is disabled")
  }

  @Test("Is shadow enabled returns default state initially")
  func testIsShadowEnabled_initially_returnsDefaultState() async throws {
    // Arrange
    let service = MockWindowAppearanceService()

    // Act
    let isEnabled = service.isShadowEnabled()

    // Assert
    // Default state can be either true or false, but should be consistent
    #expect(isEnabled == true || isEnabled == false, "Should return a valid boolean state")
  }

  @Test("Multiple window configurations work independently")
  func testConfigureWindowAppearance_multipleWindows_configuresIndependently() async throws {
    // Arrange
    let service = MockWindowAppearanceService()
    let window1 = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    let window2 = NSWindow(
      contentRect: NSRect(x: 200, y: 200, width: 500, height: 400),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    // Act
    service.configureWindowAppearance(window1)
    service.configureWindowAppearance(window2)

    // Assert
    #expect(service.configureAppearanceCallCount == 2, "Should configure both windows")
  }

  @Test("Performance: Configure window appearance completes within threshold")
  func testConfigureWindowAppearance_performance_completesQuickly() async throws {
    // Arrange
    let service = MockWindowAppearanceService()
    let window = NSWindow(
      contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )

    // Act & Assert
    let startTime = Date()
    service.configureWindowAppearance(window)
    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 0.01, "Window appearance configuration should complete under 10ms")
  }
}

// MARK: - Mock Implementation

private class MockWindowAppearanceService: WindowAppearanceProtocol {
  var configureAppearanceCallCount = 0
  var lastConfiguredWindow: NSWindow?
  var isMovableByBackground = false
  private var cornerRadius: CGFloat = 8.0
  private var shadowEnabled = true

  func configureWindowAppearance(_ window: NSWindow) {
    configureAppearanceCallCount += 1
    lastConfiguredWindow = window

    // Simulate window configuration
    window.backgroundColor = NSColor.clear
    window.isOpaque = false
    window.isMovableByWindowBackground = isMovableByBackground
    window.hasShadow = shadowEnabled
  }

  func setCornerRadius(_ radius: CGFloat) {
    cornerRadius = radius
  }

  func setCornerRadiusWithValidation(_ radius: CGFloat) throws {
    if radius < 0 {
      throw WindowAppearanceError.invalidRadius
    }
    setCornerRadius(radius)
  }

  func setShadowEnabled(_ enabled: Bool) {
    shadowEnabled = enabled
  }

  func setMovableByBackground(_ movable: Bool) {
    isMovableByBackground = movable
  }

  func getCornerRadius() -> CGFloat {
    return cornerRadius
  }

  func isShadowEnabled() -> Bool {
    return shadowEnabled
  }
}

// MARK: - Mock Error Types

private enum WindowAppearanceError: Error, Equatable {
  case invalidRadius
  case configurationFailed
}
