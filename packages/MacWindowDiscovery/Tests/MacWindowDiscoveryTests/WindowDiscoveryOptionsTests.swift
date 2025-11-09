import Testing
import Foundation
@testable import MacWindowDiscovery

@Suite("WindowDiscoveryOptions Tests")
struct WindowDiscoveryOptionsTests {

    @Test("Default preset has expected values")
    func testDefaultPreset() {
        let options = WindowDiscoveryOptions.default

        #expect(options.normalLayerOnly == true)
        #expect(options.minimumAlpha == 0.9)
        #expect(options.includeHidden == false)
        #expect(options.includeMinimized == true)
        #expect(options.useAccessibilityAPI == true)
        #expect(options.excludeSystemProcesses == true)
        #expect(options.includeInactiveSpaces == true)
    }

    @Test("Fast preset disables AX API")
    func testFastPreset() {
        let options = WindowDiscoveryOptions.fast

        #expect(options.useAccessibilityAPI == false)
        #expect(options.includeSpaceInfo == false)
        #expect(options.normalLayerOnly == false)
        #expect(options.excludeSystemProcesses == false)
    }

    @Test("Complete preset includes everything")
    func testCompletePreset() {
        let options = WindowDiscoveryOptions.complete

        #expect(options.normalLayerOnly == false)
        #expect(options.includeHidden == true)
        #expect(options.includeMinimized == true)
        #expect(options.excludeSystemProcesses == false)
        #expect(options.minimumAlpha == 0.0)
        #expect(options.minimumSize == .zero)
    }

    @Test("CLI preset filters for active space")
    func testCLIPreset() {
        let options = WindowDiscoveryOptions.cli

        #expect(options.includeInactiveSpaces == false)
        #expect(options.excludeSystemProcesses == true)
        #expect(options.normalLayerOnly == true)
    }

    @Test("Options are copyable (value semantics)")
    func testValueSemantics() {
        let options1 = WindowDiscoveryOptions.default
        var options2 = options1

        options2.includeHidden = true

        #expect(options1.includeHidden == false)
        #expect(options2.includeHidden == true)
    }

    @Test("Custom initialization works correctly")
    func testCustomInitialization() {
        let customOptions = WindowDiscoveryOptions(
            minimumSize: CGSize(width: 200, height: 100),
            normalLayerOnly: false,
            minimumAlpha: 0.5,
            includeHidden: true,
            includeMinimized: false,
            includeInactiveSpaces: false,
            bundleIdentifierWhitelist: ["com.test.app"],
            bundleIdentifierBlacklist: ["com.excluded.app"],
            excludeSystemProcesses: false,
            useAccessibilityAPI: false,
            includeSpaceInfo: false
        )

        #expect(customOptions.minimumSize.width == 200)
        #expect(customOptions.minimumSize.height == 100)
        #expect(customOptions.normalLayerOnly == false)
        #expect(customOptions.minimumAlpha == 0.5)
        #expect(customOptions.includeHidden == true)
        #expect(customOptions.includeMinimized == false)
        #expect(customOptions.includeInactiveSpaces == false)
        #expect(customOptions.bundleIdentifierWhitelist?.contains("com.test.app") == true)
        #expect(customOptions.bundleIdentifierBlacklist.contains("com.excluded.app"))
        #expect(customOptions.excludeSystemProcesses == false)
        #expect(customOptions.useAccessibilityAPI == false)
        #expect(customOptions.includeSpaceInfo == false)
    }

    @Test("Whitelist can be nil")
    func testNilWhitelist() {
        let options = WindowDiscoveryOptions.default
        #expect(options.bundleIdentifierWhitelist == nil)
    }

    @Test("Blacklist defaults to empty set")
    func testEmptyBlacklist() {
        let options = WindowDiscoveryOptions.default
        #expect(options.bundleIdentifierBlacklist.isEmpty)
    }
}
