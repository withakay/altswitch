import Testing
import CoreGraphics
@testable import MacWindowDiscovery

@Suite("WindowValidator Tests")
struct WindowValidatorTests {

    let validator = WindowValidator()

    func makeValidWindow(
        id: CGWindowID = 123,
        pid: pid_t = 456,
        width: CGFloat = 800,
        height: CGFloat = 600
    ) -> [String: Any] {
        [
            kCGWindowNumber as String: id,
            kCGWindowOwnerPID as String: pid,
            kCGWindowBounds as String: [
                "X": 0.0,
                "Y": 0.0,
                "Width": width,
                "Height": height
            ] as [String: CGFloat],
            kCGWindowAlpha as String: 1.0,
            kCGWindowLayer as String: 0
        ]
    }

    @Test("Valid window passes")
    func testValidWindow() {
        let window = makeValidWindow()
        #expect(validator.isValid(window))
    }

    @Test("Missing window number rejected")
    func testMissingWindowNumber() {
        var window = makeValidWindow()
        window.removeValue(forKey: kCGWindowNumber as String)
        #expect(!validator.isValid(window))
    }

    @Test("Missing PID rejected")
    func testMissingPID() {
        var window = makeValidWindow()
        window.removeValue(forKey: kCGWindowOwnerPID as String)
        #expect(!validator.isValid(window))
    }

    @Test("Zero window ID rejected")
    func testZeroWindowID() {
        let window = makeValidWindow(id: 0)
        #expect(!validator.isValid(window))
    }

    @Test("Zero PID rejected")
    func testZeroPID() {
        let window = makeValidWindow(pid: 0)
        #expect(!validator.isValid(window))
    }

    @Test("Missing bounds rejected")
    func testMissingBounds() {
        var window = makeValidWindow()
        window.removeValue(forKey: kCGWindowBounds as String)
        #expect(!validator.isValid(window))
    }

    @Test("Zero width rejected")
    func testZeroWidth() {
        let window = makeValidWindow(width: 0)
        #expect(!validator.isValid(window))
    }

    @Test("Zero height rejected")
    func testZeroHeight() {
        let window = makeValidWindow(height: 0)
        #expect(!validator.isValid(window))
    }

    @Test("Invalid alpha rejected")
    func testInvalidAlpha() {
        var window = makeValidWindow()
        window[kCGWindowAlpha as String] = 1.5  // > 1.0
        #expect(!validator.isValid(window))

        window[kCGWindowAlpha as String] = -0.5  // < 0.0
        #expect(!validator.isValid(window))
    }

    @Test("Invalid layer rejected")
    func testInvalidLayer() {
        var window = makeValidWindow()
        window[kCGWindowLayer as String] = 10000  // Too high
        #expect(!validator.isValid(window))
    }
}
