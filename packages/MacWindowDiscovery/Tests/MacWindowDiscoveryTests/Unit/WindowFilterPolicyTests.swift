import Testing
import CoreGraphics
@testable import MacWindowDiscovery

@Suite("WindowFilterPolicy Tests")
struct WindowFilterPolicyTests {

    func makeWindow(
        width: CGFloat = 800,
        height: CGFloat = 600,
        alpha: Double = 1.0,
        layer: Int = 0
    ) -> [String: Any] {
        [
            kCGWindowBounds as String: [
                "X": 0.0,
                "Y": 0.0,
                "Width": width,
                "Height": height
            ] as [String: CGFloat],
            kCGWindowAlpha as String: alpha,
            kCGWindowLayer as String: layer
        ]
    }

    @Test("Size filtering works")
    func testSizeFilter() {
        var options = WindowDiscoveryOptions.default
        options.minimumSize = CGSize(width: 100, height: 100)

        let policy = WindowFilterPolicy(options: options)

        // Too small
        let small = makeWindow(width: 50, height: 50)
        #expect(!policy.shouldInclude(small, axInfo: nil, appInfo: nil))

        // Large enough
        let large = makeWindow(width: 200, height: 200)
        #expect(policy.shouldInclude(large, axInfo: nil, appInfo: nil))
    }

    @Test("Alpha filtering works")
    func testAlphaFilter() {
        var options = WindowDiscoveryOptions.default
        options.minimumAlpha = 0.9

        let policy = WindowFilterPolicy(options: options)

        // Too transparent
        let transparent = makeWindow(alpha: 0.5)
        #expect(!policy.shouldInclude(transparent, axInfo: nil, appInfo: nil))

        // Opaque enough
        let opaque = makeWindow(alpha: 1.0)
        #expect(policy.shouldInclude(opaque, axInfo: nil, appInfo: nil))
    }

    @Test("Layer filtering works")
    func testLayerFilter() {
        var options = WindowDiscoveryOptions.default
        options.normalLayerOnly = true

        let policy = WindowFilterPolicy(options: options)

        // Non-normal layer
        let floating = makeWindow(layer: 10)
        #expect(!policy.shouldInclude(floating, axInfo: nil, appInfo: nil))

        // Normal layer
        let normal = makeWindow(layer: 0)
        #expect(policy.shouldInclude(normal, axInfo: nil, appInfo: nil))
    }

    @Test("Hidden filtering works")
    func testHiddenFilter() {
        var options = WindowDiscoveryOptions.default
        options.includeHidden = false

        let policy = WindowFilterPolicy(options: options)
        let window = makeWindow()

        // Hidden window
        let hiddenInfo = AXWindowInfo(isHidden: true)
        #expect(!policy.shouldInclude(window, axInfo: hiddenInfo, appInfo: nil))

        // Visible window
        let visibleInfo = AXWindowInfo(isHidden: false)
        #expect(policy.shouldInclude(window, axInfo: visibleInfo, appInfo: nil))
    }

    @Test("Minimized filtering works")
    func testMinimizedFilter() {
        var options = WindowDiscoveryOptions.default
        options.includeMinimized = false

        let policy = WindowFilterPolicy(options: options)
        let window = makeWindow()

        // Minimized window
        let minimizedInfo = AXWindowInfo(isMinimized: true)
        #expect(!policy.shouldInclude(window, axInfo: minimizedInfo, appInfo: nil))

        // Normal window
        let normalInfo = AXWindowInfo(isMinimized: false)
        #expect(policy.shouldInclude(window, axInfo: normalInfo, appInfo: nil))
    }

    @Test("Whitelist filtering works")
    func testWhitelistFilter() {
        var options = WindowDiscoveryOptions.default
        options.bundleIdentifierWhitelist = ["com.apple.Safari"]

        let policy = WindowFilterPolicy(options: options)
        let window = makeWindow()

        // Whitelisted app
        let safariApp = AppInfo(
            processID: 123,
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            activationPolicy: 0
        )
        #expect(policy.shouldInclude(window, axInfo: nil, appInfo: safariApp))

        // Non-whitelisted app
        let chromeApp = AppInfo(
            processID: 456,
            bundleIdentifier: "com.google.Chrome",
            localizedName: "Chrome",
            activationPolicy: 0
        )
        #expect(!policy.shouldInclude(window, axInfo: nil, appInfo: chromeApp))
    }

    @Test("Blacklist filtering works")
    func testBlacklistFilter() {
        var options = WindowDiscoveryOptions.default
        options.bundleIdentifierBlacklist = ["com.unwanted.app"]

        let policy = WindowFilterPolicy(options: options)
        let window = makeWindow()

        // Blacklisted app
        let unwantedApp = AppInfo(
            processID: 123,
            bundleIdentifier: "com.unwanted.app",
            localizedName: "Unwanted",
            activationPolicy: 0
        )
        #expect(!policy.shouldInclude(window, axInfo: nil, appInfo: unwantedApp))

        // Normal app
        let normalApp = AppInfo(
            processID: 456,
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            activationPolicy: 0
        )
        #expect(policy.shouldInclude(window, axInfo: nil, appInfo: normalApp))
    }

    @Test("System process filtering works")
    func testSystemProcessFilter() {
        var options = WindowDiscoveryOptions.default
        options.excludeSystemProcesses = true

        let policy = WindowFilterPolicy(options: options)
        let window = makeWindow()

        // System process
        let dockApp = AppInfo(
            processID: 123,
            bundleIdentifier: "com.apple.dock",
            localizedName: "Dock",
            activationPolicy: 0
        )
        #expect(!policy.shouldInclude(window, axInfo: nil, appInfo: dockApp))

        // User app
        let userApp = AppInfo(
            processID: 456,
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            activationPolicy: 0
        )
        #expect(policy.shouldInclude(window, axInfo: nil, appInfo: userApp))
    }
}
