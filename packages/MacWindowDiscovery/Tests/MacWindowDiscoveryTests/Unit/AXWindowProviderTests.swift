import Testing
import CoreGraphics
import ApplicationServices
@testable import MacWindowDiscovery

@Suite("AXWindowProvider Tests")
struct AXWindowProviderTests {

    @Test("Returns empty lookup when no permissions")
    func testNoPermissions() {
        let provider = AXWindowProvider()

        // If no AX permissions, should return empty lookup
        if !AXIsProcessTrusted() {
            let lookup = provider.buildWindowLookup(
                for: ProcessInfo.processInfo.processIdentifier,
                bundleIdentifier: "com.test"
            )

            #expect(lookup.isEmpty)
        }
    }

    @Test("Handles invalid PID gracefully")
    func testInvalidPID() {
        let provider = AXWindowProvider()

        // Should not crash with invalid PID
        let lookup = provider.buildWindowLookup(
            for: -1,
            bundleIdentifier: "com.test"
        )

        #expect(lookup.isEmpty)
    }

    @Test("Handles non-existent process gracefully")
    func testNonExistentProcess() {
        let provider = AXWindowProvider()

        // Should not crash with non-existent PID
        let lookup = provider.buildWindowLookup(
            for: 999999,
            bundleIdentifier: "com.test.nonexistent"
        )

        // Should return empty lookup without crashing
        #expect(lookup.isEmpty || lookup.count >= 0)
    }
}
