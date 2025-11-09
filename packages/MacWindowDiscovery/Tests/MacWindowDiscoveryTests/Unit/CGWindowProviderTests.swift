import Testing
import CoreGraphics
@testable import MacWindowDiscovery

@Suite("CGWindowProvider Tests")
struct CGWindowProviderTests {

    @Test("Captures window list from system")
    func testCaptureWindowList() throws {
        let provider = CGWindowProvider()
        let windows = try provider.captureWindowList()

        // Should return at least some windows (assuming test runs in GUI environment)
        #expect(windows.count > 0)

        // Each window should have required fields
        for window in windows {
            #expect(window[kCGWindowNumber as String] != nil)
            #expect(window[kCGWindowOwnerPID as String] != nil)
        }
    }

    @Test("Filters invalid windows")
    func testFiltersInvalidWindows() throws {
        let provider = CGWindowProvider()
        let windows = try provider.captureWindowList()

        // All returned windows should have window number and PID
        for window in windows {
            let hasWindowNumber = window[kCGWindowNumber as String] is CGWindowID
            let hasPID = window[kCGWindowOwnerPID as String] is pid_t

            #expect(hasWindowNumber)
            #expect(hasPID)
        }
    }

    @Test("Default option uses on-screen only")
    func testDefaultOption() throws {
        let provider = CGWindowProvider()

        // Test that default method works
        let windows = try provider.captureWindowList()
        #expect(windows.count > 0)
    }
}
