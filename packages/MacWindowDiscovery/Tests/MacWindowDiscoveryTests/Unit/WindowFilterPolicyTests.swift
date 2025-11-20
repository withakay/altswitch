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
        options.requireProperSubrole = false  // Disable for unit testing

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
        options.requireProperSubrole = false  // Disable for unit testing

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
        options.requireProperSubrole = false  // Disable for unit testing

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
        options.requireProperSubrole = false  // Disable for unit testing

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
        options.requireProperSubrole = false  // Disable for unit testing

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
        options.requireProperSubrole = false  // Disable for unit testing

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
        options.requireProperSubrole = false  // Disable for unit testing

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
        options.requireProperSubrole = false  // Disable for unit testing

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

    @Test("Application name exclude list filters all windows")
    func testApplicationNameExcludeList() {
        var options = WindowDiscoveryOptions.default
        options.applicationNameExcludeList = ["Slack", "Discord"]
        options.requireProperSubrole = false  // Disable for unit testing

        let policy = WindowFilterPolicy(options: options)
        
        // Excluded app with titled window
        var windowWithTitle = makeWindow()
        windowWithTitle[kCGWindowName as String] = "Channel #general"
        let slackApp = AppInfo(
            processID: 123,
            bundleIdentifier: "com.slack.Slack",
            localizedName: "Slack",
            activationPolicy: 0
        )
        #expect(!policy.shouldInclude(windowWithTitle, axInfo: nil, appInfo: slackApp))
        
        // Excluded app with untitled window
        let windowWithoutTitle = makeWindow()
        #expect(!policy.shouldInclude(windowWithoutTitle, axInfo: nil, appInfo: slackApp))
        
        // Non-excluded app
        let safariApp = AppInfo(
            processID: 456,
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            activationPolicy: 0
        )
        #expect(policy.shouldInclude(windowWithTitle, axInfo: nil, appInfo: safariApp))
    }

    @Test("Untitled window exclude list filters only untitled windows")
    func testUntitledWindowExcludeList() {
        var options = WindowDiscoveryOptions.default
        options.untitledWindowExcludeList = ["Terminal"]
        options.requireProperSubrole = false  // Disable for unit testing

        let policy = WindowFilterPolicy(options: options)
        
        let terminalApp = AppInfo(
            processID: 123,
            bundleIdentifier: "com.apple.Terminal",
            localizedName: "Terminal",
            activationPolicy: 0
        )
        
        // Untitled window - should be excluded (no CG title, no AX title)
        let untitledWindow = makeWindow()
        #expect(!policy.shouldInclude(untitledWindow, axInfo: nil, appInfo: terminalApp))
        
        // Window with CG title - should pass through
        var windowWithCGTitle = makeWindow()
        windowWithCGTitle[kCGWindowName as String] = "bash - 80x24"
        #expect(policy.shouldInclude(windowWithCGTitle, axInfo: nil, appInfo: terminalApp))
        
        // Window with AX title - should pass through
        let windowWithAXTitle = makeWindow()
        let axInfo = AXWindowInfo(title: "zsh - 100x30")
        #expect(policy.shouldInclude(windowWithAXTitle, axInfo: axInfo, appInfo: terminalApp))
        
        // Different app with untitled window - should pass through
        let safariApp = AppInfo(
            processID: 456,
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            activationPolicy: 0
        )
        #expect(policy.shouldInclude(untitledWindow, axInfo: nil, appInfo: safariApp))
    }

    @Test("Both exclude lists work together")
    func testBothExcludeLists() {
        var options = WindowDiscoveryOptions.default
        options.applicationNameExcludeList = ["Music"]
        options.untitledWindowExcludeList = ["Terminal"]
        options.requireProperSubrole = false  // Disable for unit testing

        let policy = WindowFilterPolicy(options: options)
        
        // Music app - all windows excluded
        let musicApp = AppInfo(
            processID: 123,
            bundleIdentifier: "com.apple.Music",
            localizedName: "Music",
            activationPolicy: 0
        )
        var titledWindow = makeWindow()
        titledWindow[kCGWindowName as String] = "Now Playing"
        #expect(!policy.shouldInclude(titledWindow, axInfo: nil, appInfo: musicApp))
        #expect(!policy.shouldInclude(makeWindow(), axInfo: nil, appInfo: musicApp))
        
        // Terminal app - only untitled windows excluded
        let terminalApp = AppInfo(
            processID: 456,
            bundleIdentifier: "com.apple.Terminal",
            localizedName: "Terminal",
            activationPolicy: 0
        )
        #expect(!policy.shouldInclude(makeWindow(), axInfo: nil, appInfo: terminalApp))
        var terminalTitled = makeWindow()
        terminalTitled[kCGWindowName as String] = "bash"
        #expect(policy.shouldInclude(terminalTitled, axInfo: nil, appInfo: terminalApp))
        
        // Normal app - all windows pass through
        let safariApp = AppInfo(
            processID: 789,
            bundleIdentifier: "com.apple.Safari",
            localizedName: "Safari",
            activationPolicy: 0
        )
        #expect(policy.shouldInclude(titledWindow, axInfo: nil, appInfo: safariApp))
        #expect(policy.shouldInclude(makeWindow(), axInfo: nil, appInfo: safariApp))
    }

    @Test("Exclude lists handle nil app info gracefully")
    func testExcludeListsWithNilAppInfo() {
        var options = WindowDiscoveryOptions.default
        options.applicationNameExcludeList = ["Slack"]
        options.untitledWindowExcludeList = ["Terminal"]
        options.requireProperSubrole = false  // Disable for unit testing

        let policy = WindowFilterPolicy(options: options)
        let window = makeWindow()
        
        // Should pass through when appInfo is nil
        #expect(policy.shouldInclude(window, axInfo: nil, appInfo: nil))
    }

    @Test("Exclude lists handle nil localized name gracefully")
    func testExcludeListsWithNilLocalizedName() {
        var options = WindowDiscoveryOptions.default
        options.applicationNameExcludeList = ["Slack"]
        options.untitledWindowExcludeList = ["Terminal"]
        options.requireProperSubrole = false  // Disable for unit testing

        let policy = WindowFilterPolicy(options: options)
        let window = makeWindow()
        
        // App with nil localized name
        let appWithoutName = AppInfo(
            processID: 123,
            bundleIdentifier: "com.example.app",
            localizedName: nil,
            activationPolicy: 0
        )
        
        // Should pass through when localizedName is nil
        #expect(policy.shouldInclude(window, axInfo: nil, appInfo: appWithoutName))
    }

    @Test("Exclude lists are case-sensitive")
    func testExcludeListsCaseSensitive() {
        var options = WindowDiscoveryOptions.default
        options.applicationNameExcludeList = ["Slack"]
        options.requireProperSubrole = false  // Disable for unit testing

        let policy = WindowFilterPolicy(options: options)
        let window = makeWindow()
        
        // Exact match - excluded
        let slackApp = AppInfo(
            processID: 123,
            bundleIdentifier: "com.slack.Slack",
            localizedName: "Slack",
            activationPolicy: 0
        )
        #expect(!policy.shouldInclude(window, axInfo: nil, appInfo: slackApp))
        
        // Different case - not excluded
        let slackLowerApp = AppInfo(
            processID: 456,
            bundleIdentifier: "com.slack.Slack",
            localizedName: "slack",
            activationPolicy: 0
        )
        #expect(policy.shouldInclude(window, axInfo: nil, appInfo: slackLowerApp))
    }
}
