//
//  SimpleTest.swift
//  AltSwitchTests
//
//  Simple test to verify testing framework works
//

import Testing

@testable import AltSwitch

@Suite("Simple Tests")
struct SimpleTests {

  @Test("Basic addition test")
  func testBasicAddition() async throws {
    // Arrange
    let a = 2
    let b = 2

    // Act
    let result = a + b

    // Assert
    #expect(result == 4, "2 + 2 should equal 4")
  }

  @Test("Test AppInfo creation")
  func testAppInfoCreation() async throws {
    // Arrange
    let appInfo = AppInfo.preview

    // Assert
    #expect(appInfo.bundleIdentifier == "com.example.app", "Bundle identifier should match")
    #expect(appInfo.localizedName == "Example App", "Localized name should match")
    #expect(appInfo.processIdentifier == 1234, "Process identifier should match")
  }
}
