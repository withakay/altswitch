import Testing
import Foundation
import CoreGraphics
@testable import MacWindowDiscovery

@Suite("WindowInfo Tests")
struct WindowInfoTests {

    // MARK: - Test Data Factory

    func makeTestWindow(
        id: UInt32 = 123,
        title: String = "Test Window",
        bundleIdentifier: String? = "com.test.app",
        applicationName: String? = "Test App",
        subrole: String? = "AXStandardWindow"
    ) -> WindowInfo {
        WindowInfo(
            id: id,
            title: title,
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            alpha: 1.0,
            isOnScreen: true,
            layer: 0,
            processID: 1234,
            bundleIdentifier: bundleIdentifier,
            applicationName: applicationName,
            isMinimized: false,
            isHidden: false,
            isFullscreen: false,
            isFocused: true,
            isMainWindow: true,
            isTabbed: false,
            spaceIDs: [1],
            isOnAllSpaces: false,
            desktopNumber: 1,
            displayID: 1,
            role: "AXWindow",
            subrole: subrole,
            capturedAt: Date()
        )
    }

    // MARK: - Codable Tests

    @Test("WindowInfo is Codable")
    func testCodable() throws {
        let original = makeTestWindow()
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(WindowInfo.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.title == original.title)
        #expect(decoded.bundleIdentifier == original.bundleIdentifier)
        #expect(decoded.processID == original.processID)
    }

    // MARK: - Hashable Tests

    @Test("WindowInfo is Hashable")
    func testHashable() {
        let window1 = makeTestWindow(id: 123)
        let window2 = makeTestWindow(id: 123)
        let window3 = makeTestWindow(id: 456)

        #expect(window1 == window2)
        #expect(window1 != window3)

        let set = Set([window1, window2, window3])
        #expect(set.count == 2)
    }

    // MARK: - Computed Property Tests

    @Test("displayName returns title when present")
    func testDisplayNameWithTitle() {
        let window = makeTestWindow(title: "My Window")
        #expect(window.displayName == "My Window")
    }

    @Test("displayName returns app name when title empty")
    func testDisplayNameWithoutTitle() {
        let window = makeTestWindow(title: "", applicationName: "Test App")
        #expect(window.displayName == "Test App")
    }

    @Test("displayName returns bundle ID when no title or app name")
    func testDisplayNameWithBundleID() {
        let window = makeTestWindow(
            title: "",
            bundleIdentifier: "com.test.app",
            applicationName: nil
        )
        #expect(window.displayName == "com.test.app")
    }

    @Test("displayName returns Unknown Window when no identifiers")
    func testDisplayNameFallback() {
        let window = makeTestWindow(
            title: "",
            bundleIdentifier: nil,
            applicationName: nil
        )
        #expect(window.displayName == "Unknown Window")
    }

    @Test("isStandardWindow detects AXStandardWindow")
    func testIsStandardWindowForStandardWindow() {
        let window = makeTestWindow(subrole: "AXStandardWindow")
        #expect(window.isStandardWindow == true)
    }

    @Test("isStandardWindow detects AXDialog")
    func testIsStandardWindowForDialog() {
        let window = makeTestWindow(subrole: "AXDialog")
        #expect(window.isStandardWindow == true)
    }

    @Test("isStandardWindow rejects non-standard windows")
    func testIsStandardWindowForNonStandard() {
        let window = makeTestWindow(subrole: "AXSystemDialog")
        #expect(window.isStandardWindow == false)
    }

    @Test("isStandardWindow rejects nil subrole")
    func testIsStandardWindowForNilSubrole() {
        let window = makeTestWindow(subrole: nil)
        #expect(window.isStandardWindow == false)
    }
}
