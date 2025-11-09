import Testing
import CoreGraphics
@testable import MacWindowDiscovery

@Suite("WindowInfoBuilder Tests")
struct WindowInfoBuilderTests {

    let builder = WindowInfoBuilder()

    func makeCGData() -> [String: Any] {
        [
            kCGWindowNumber as String: CGWindowID(123),
            kCGWindowOwnerPID as String: pid_t(456),
            kCGWindowName as String: "CG Title",
            kCGWindowBounds as String: [
                "X": 100.0,
                "Y": 200.0,
                "Width": 800.0,
                "Height": 600.0
            ] as [String: CGFloat],
            kCGWindowAlpha as String: 1.0,
            kCGWindowLayer as String: 0,
            kCGWindowIsOnscreen as String: true
        ]
    }

    @Test("Builds basic WindowInfo")
    func testBasicBuild() async {
        let cgData = makeCGData()
        let info = await builder.buildWindowInfo(
            from: cgData,
            axInfo: nil,
            appInfo: nil,
            spaces: []
        )

        #expect(info.id == 123)
        #expect(info.processID == 456)
        #expect(info.title == "CG Title")
        #expect(info.bounds.width == 800)
        #expect(info.bounds.height == 600)
    }

    @Test("Prefers AX title over CG title")
    func testTitlePriority() async {
        let cgData = makeCGData()
        let axInfo = AXWindowInfo(title: "AX Title")

        let info = await builder.buildWindowInfo(
            from: cgData,
            axInfo: axInfo,
            appInfo: nil,
            spaces: []
        )

        #expect(info.title == "AX Title")
    }

    @Test("Uses CG title when no AX title")
    func testCGTitleFallback() async {
        let cgData = makeCGData()
        let axInfo = AXWindowInfo(title: nil)

        let info = await builder.buildWindowInfo(
            from: cgData,
            axInfo: axInfo,
            appInfo: nil,
            spaces: []
        )

        #expect(info.title == "CG Title")
    }

    @Test("Includes app metadata")
    func testAppMetadata() async {
        let cgData = makeCGData()
        let appInfo = AppInfo(
            processID: 456,
            bundleIdentifier: "com.test.app",
            localizedName: "Test App",
            activationPolicy: 0
        )

        let info = await builder.buildWindowInfo(
            from: cgData,
            axInfo: nil,
            appInfo: appInfo,
            spaces: []
        )

        #expect(info.bundleIdentifier == "com.test.app")
        #expect(info.applicationName == "Test App")
    }

    @Test("Includes AX state")
    func testAXState() async {
        let cgData = makeCGData()
        let axInfo = AXWindowInfo(
            isMinimized: true,
            isHidden: false,
            isFullscreen: false,
            isFocused: true,
            role: "AXWindow",
            subrole: "AXStandardWindow"
        )

        let info = await builder.buildWindowInfo(
            from: cgData,
            axInfo: axInfo,
            appInfo: nil,
            spaces: []
        )

        #expect(info.isMinimized == true)
        #expect(info.isHidden == false)
        #expect(info.isFocused == true)
        #expect(info.role == "AXWindow")
        #expect(info.subrole == "AXStandardWindow")
    }

    @Test("Includes space information")
    func testSpaces() async {
        let cgData = makeCGData()

        let info = await builder.buildWindowInfo(
            from: cgData,
            axInfo: nil,
            appInfo: nil,
            spaces: [1, 2]
        )

        #expect(info.spaceIDs == [1, 2])
        #expect(info.isOnAllSpaces == true)  // Multiple spaces
    }

    @Test("Handles missing data gracefully")
    func testMissingData() async {
        let cgData: [String: Any] = [:]  // Empty data

        let info = await builder.buildWindowInfo(
            from: cgData,
            axInfo: nil,
            appInfo: nil,
            spaces: []
        )

        #expect(info.id == 0)
        #expect(info.processID == 0)
        #expect(info.title == "")
        #expect(info.bounds == .zero)
    }
}
