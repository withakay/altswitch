# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
AltSwitch is a macOS Spotlight-style app switcher using modern Swift/SwiftUI with TDD practices. The app provides fast fuzzy-search app switching via global hotkeys with a Liquid Glass UI effect.

### Key Reference Documents
Before starting work, familiarize yourself with these critical documents:
- **CLAUDE.md** (this file) - Development guidelines and architecture
- **AGENTS.md** - Specialized agents and OpenSpec workflow
- **PRIVATE_APIS_README.md** - Private API documentation index
- **CHANGELOG.md** - Version history and changes
- **docs/window-discovery-package/INDEX.md** - Window discovery architecture

## Source Control

**IMPORTANT**: This project uses **Jujutsu (`jj`)** for source control, not git. While git commands may work, prefer using jj commands for all source control operations.

```bash
# Common jj commands
jj status              # Check working copy status
jj diff                # Show changes
jj commit -m "msg"     # Create a commit
jj log                 # View commit history
```

## Development Commands

### Build & Run
```bash
# Build the app (output: build/Build/Products/Debug/AltSwitch.app)
xcodebuild -scheme AltSwitch -configuration Debug build

# Run the app
open build/Build/Products/Debug/AltSwitch.app

# Build for release
xcodebuild -scheme AltSwitch -configuration Release archive
```

### Testing (TDD Workflow)
```bash
# Run all tests (unit + UI)
xcodebuild test -scheme AltSwitch -destination 'platform=macOS'

# Run only unit tests (Swift Testing framework)
xcodebuild test -scheme AltSwitch -only-testing:AltSwitchTests

# Run specific test
xcodebuild test -scheme AltSwitch -only-testing:AltSwitchTests/AppManagerTests/testRunningAppsDiscovery

# Run UI tests
xcodebuild test -scheme AltSwitch -only-testing:AltSwitchUITests

# Generate test coverage report
xcodebuild test -scheme AltSwitch -enableCodeCoverage YES
xcrun xcresulttool get --path TestResults.xcresult --format json
```

### Code Quality
```bash
# Format Swift code (requires swift-format)
swift-format -i -r AltSwitch/

# Lint Swift code
swiftlint lint --path AltSwitch/

# Analyze for potential issues
xcodebuild analyze -scheme AltSwitch
```

## Architecture & Implementation Guidelines

### Core Architecture Patterns
- **MVVM with ObservableObject**: All ViewModels should be @MainActor classes conforming to ObservableObject
- **Dependency Injection**: Use environment objects and initializer injection, avoid singletons
- **Protocol-Oriented**: Define protocols for services (AppDiscoveryProtocol, HotkeyManagerProtocol, etc.)
- **Async/Await**: All async operations use modern Swift concurrency, no completion handlers

### Swift/SwiftUI Modern Features (Swift 6.0+)
```swift
// Use @Observable macro for models (iOS 17+/macOS 14+)
@Observable
final class AppManager {
    var apps: [AppInfo] = []
}

// Use #Preview macro for SwiftUI previews
#Preview("Dark Mode") {
    MainWindow()
        .preferredColorScheme(.dark)
}

// Strict concurrency checking with @MainActor
@MainActor
final class MainViewModel: ObservableObject { }

// Use typed throws (Swift 6.0)
enum AppSwitchError: Error {
    case accessibilityDenied
    case appNotFound
}
func switchToApp(_ app: AppInfo) throws(AppSwitchError) { }
```

### TDD Requirements
1. **Write tests first**: Every new feature starts with a failing test
2. **Test file structure**: Mirror source structure in Tests/ directory
3. **Use Swift Testing framework** for new tests (not XCTest for unit tests)
4. **Test naming**: `test_methodName_condition_expectedResult()`
5. **Minimum coverage**: 80% for business logic, 60% for UI

Example test structure:
```swift
import Testing
@testable import AltSwitch

@Suite("AppManager Tests")
struct AppManagerTests {
    @Test("Discovers running applications")
    func testRunningAppsDiscovery() async throws {
        let manager = AppManager(workspace: MockWorkspace())
        let apps = try await manager.fetchRunningApps()
        #expect(apps.count > 0)
    }
}
```

### Window Management Implementation
The app uses three APIs for window/app management:
1. **NSWorkspace**: Running applications discovery
2. **CGWindowListCopyWindowInfo**: Window details and matching
3. **AXUIElement**: Accessibility API for app switching

Always request permissions before using Accessibility APIs:
```swift
let trusted = AXIsProcessTrusted()
if !trusted {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
    AXIsProcessTrustedWithOptions(options)
}
```

### AXElementCache - Critical for Cross-Space Switching
**Location**: `AltSwitch/Services/Platform/AXElementCache.swift`

AltSwitch uses a singleton `AXElementCache` to cache AXUIElement references for windows. This is **CRITICAL** for cross-space window switching:

**Why It's Needed**:
- When a window is on a different space, it cannot be accessed via normal AX APIs
- We must cache the AXUIElement when the window is first discovered (accessible)
- The cached element can then be used later to activate windows on other spaces

**Usage Pattern**:
```swift
// During discovery - cache the element when accessible
let element = AXUIElementCreateApplication(app.processIdentifier)
AXElementCache.shared.set(element, for: windowID)

// During activation - retrieve cached element for cross-space switching
if let cachedElement = AXElementCache.shared.get(for: windowID) {
    // Use cached element to activate window on different space
}
```

**Thread Safety**: The cache is `@MainActor` isolated and must only be accessed from the main thread.

### UI Implementation Requirements
1. **Detached Window**: Use `.windowStyle(.hiddenTitleBar)` and custom positioning
2. **Liquid Glass Effect**: Apply `.glassBackgroundEffect()` modifier (macOS 15+)
3. **Keyboard Focus**: Maintain TextField focus with `.focused()` and FocusState
4. **Animation**: All state changes should use `.animation(.spring, value:)`

### Global Keystroke Forwarding System
AltSwitch implements automatic keystroke forwarding to search box using NSEvent monitoring:

#### NSEvent Monitoring Architecture
```swift
// Use local event monitoring for in-app keystroke handling
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    // Process and route keystrokes to search box
    return shouldHandleEvent(event) ? nil : event
}
```

#### Keystroke Classification Logic
```swift
// Character classification using Foundation CharacterSet
func isPrintableKeystroke(_ event: NSEvent) -> Bool {
    guard let characters = event.characters, !characters.isEmpty else { return false }
    return characters.unicodeScalars.allSatisfy { scalar in
        CharacterSet.alphanumerics.contains(scalar) ||
        CharacterSet.punctuationCharacters.contains(scalar) ||
        CharacterSet.symbols.contains(scalar) ||
        scalar.value == 32 // space character
    }
}

// Modifier key detection
func hasModifierKeys(_ event: NSEvent) -> Bool {
    let relevantModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .function]
    return !event.modifierFlags.intersection(relevantModifiers).isEmpty
}
```

#### Focus Management Integration
```swift
// Use SwiftUI's @FocusState for programmatic focus control
@FocusState private var isSearchFocused: Bool

// Automatic focus management
.onChange(of: viewModel.isVisible) { _, isVisible in
    if isVisible {
        DispatchQueue.main.async {
            isSearchFocused = true
        }
    }
}
```

#### Performance Requirements
- **Keystroke latency**: <10ms processing time
- **Character debouncing**: For rapid typing (>10 chars/sec)
- **No dropped characters**: Even during fast input
- **IME support**: Native composition handling via SwiftUI TextField

#### International Input Support
- **Unicode characters**: Full support via CharacterSet
- **IME composition**: Let SwiftUI TextField handle natively
- **Keyboard layouts**: Works with international layouts
- **Emoji and symbols**: Proper character classification

### Global Hotkey System
AltSwitch uses the KeyboardShortcuts framework for modern, robust hotkey management:

#### KeyboardShortcuts Integration
```swift
import KeyboardShortcuts

// Define hotkey names
extension KeyboardShortcuts.Name {
    static let showHide = Self("showHide", default: .init(.space, modifiers: [.command, .shift]))
    static let settings = Self("settings", default: .init(.comma, modifiers: [.command]))
    static let refresh = Self("refresh", default: .init(.r, modifiers: [.command, .shift]))
}

// Register hotkeys
KeyboardShortcuts.onKeyUp(for: .showHide) {
    // Handle show/hide action
}
```

#### Hotkey Architecture
- **KeyCombo Model**: Enhanced wrapper around KeyboardShortcuts.Shortcut with validation
- **HotkeyErrorHandler**: Centralized conflict detection and resolution
- **Performance**: All registrations must complete within 100ms
- **Accessibility**: Full VoiceOver support via AccessibilityAnnouncer

#### Conflict Resolution Strategy
1. **Validation**: Check for system conflicts before registration
2. **Detection**: Identify conflicting applications using heuristics
3. **Alternatives**: Auto-suggest alternative key combinations
4. **Recovery**: Graceful fallback with user-friendly error messages

#### Error Handling Patterns
```swift
// Use HotkeyErrorHandler for consistent error handling
let errorHandler = HotkeyErrorHandler()

do {
    try await hotkeyManager.register(combo) { }
} catch {
    errorHandler.handleError(error, for: combo)
    
    // Attempt automatic resolution
    if let alternative = await errorHandler.registerWithConflictResolution(combo, registrationHandler: hotkeyManager.register) {
        print("Successfully registered alternative: \(alternative.displayString)")
    }
}
```

### Configuration Storage
Settings stored as YAML in `~/.config/altswitch/settings.yaml`:
- Use Yams library for YAML parsing
- Create ConfigManager as @Observable class
- Auto-save on property changes using onChange

## Project Structure Standards

### File Organization
```
AltSwitch/
├── Models/           # Data models (@Observable classes, Codable structs)
├── Views/            # SwiftUI views (keep small, < 150 lines)
│   └── Preferences/  # Preferences interface (Browserino-inspired architecture)
│       ├── PreferencesView.swift    # Main container with TabView
│       ├── GeneralTab.swift         # General settings tab
│       ├── HotkeysTab.swift         # Hotkey configuration tab
│       ├── AppearanceTab.swift      # Visual appearance settings
│       └── Components/              # Shared preference components
│           ├── PermissionStatusRow.swift
│           ├── HotkeySection.swift
│           ├── StatusMessagesView.swift
│           ├── ValidationErrorsView.swift
│           └── HotkeyTipsView.swift
├── ViewModels/       # @MainActor ObservableObject classes
├── Services/         # Business logic (protocols + implementations)
│   ├── AppManagement/        # App discovery and switching
│   ├── Search/               # Fuzzy search implementation
│   ├── Input/                # Event interception and hotkeys
│   └── Platform/             # Platform-specific code
│       ├── Spaces/           # Space switching and private APIs
│       └── AXElementCache.swift  # Critical for cross-space switching
├── Adapters/         # Adapter pattern implementations
│   └── PackageAppDiscovery.swift  # Future window discovery package adapter
├── Core/             # Core protocols and contracts
│   └── Protocols/
├── Utilities/        # Extensions, helpers
└── Resources/        # Assets, localizations
```

### Adapter Pattern
The codebase uses the Adapter pattern to integrate with external packages:
- **Location**: `AltSwitch/Adapters/`
- **Purpose**: Wrap external package APIs to match internal protocols
- **Example**: `PackageAppDiscovery.swift` adapts the future Window Discovery Package to `AppDiscoveryProtocol`
- **Benefits**: Allows swapping implementations without changing core code

### Naming Conventions
- **Views**: Suffix with `View` (e.g., `AppListView`)
- **ViewModels**: Suffix with `ViewModel` (e.g., `MainViewModel`)
- **Services**: Suffix with `Service` or `Manager` (e.g., `AppDiscoveryService`)
- **Protocols**: Suffix with `Protocol` or use -able/-ing (e.g., `Searchable`)

## Performance Requirements
- Window appearance: < 100ms
- Search response: < 50ms (use debouncing)
- App switching: < 200ms
- Memory usage: < 50MB baseline

## Accessibility & Permissions
Required entitlements in Info.plist:
- `com.apple.security.automation.apple-events` (for app control)
- `com.apple.security.accessibility` (for window management)

Always handle permission denial gracefully with clear user instructions.

## Dependencies Management
Current dependencies (add via Xcode Package Manager):
```swift
// File > Add Package Dependencies
https://github.com/jpsim/Yams.git                    // YAML parsing
https://github.com/apple/swift-async-algorithms      // Async utilities
https://github.com/sindresorhus/KeyboardShortcuts    // Global hotkey management
```

### KeyboardShortcuts Framework Benefits
- **Native macOS Integration**: Uses system APIs for optimal performance
- **Automatic Conflict Detection**: Built-in system shortcut awareness
- **User Preferences**: Integrates with System Preferences for user customization
- **Accessibility**: Full support for assistive technologies
- **Memory Efficient**: Minimal overhead compared to custom implementations

## Critical Implementation Notes
1. **Never modify NSWorkspace.shared directly** - it's read-only
2. **CGWindowListCopyWindowInfo returns unmanaged objects** - handle memory properly
3. **AXUIElement calls must be on main thread** for UI updates
4. **Test Accessibility APIs in sandbox** - behavior differs from non-sandboxed
5. **Use debouncing for search** - combine with AsyncAlgorithms.debounce
6. **KeyboardShortcuts registration is async** - always use proper error handling
7. **Settings migration is automatic** - SettingsMigrator handles version upgrades

## CGEventTap Implementation Guide

### Critical Implementation Notes for Alt+Tab and Cmd+Tab Interception

#### 1. CGEventTap Callback Requirements
```swift
// MUST use global C-style function, NOT closure
func eventTapCallback(proxy: CGEventTapProxy,
                      type: CGEventType,
                      event: CGEvent,
                      refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    // Get self from refcon
    let interceptor = Unmanaged<SystemEventInterceptor>.fromOpaque(refcon).takeUnretainedValue()
    return interceptor.handleEvent(proxy: proxy, type: type, event: event)
}

// Pass self as refcon
let selfPointer = Unmanaged.passUnretained(self).toOpaque()
CGEvent.tapCreate(..., userInfo: selfPointer)
```

#### 2. Run Loop Integration
```swift
// CRITICAL: Must add to MAIN run loop, not current!
CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
// NOT: CFRunLoopGetCurrent()
```

#### 3. Permission Requirements
- Requires BOTH Accessibility AND Input Monitoring permissions
- Debug builds create new app signatures on each rebuild
- May need to manually re-grant permissions after rebuild
- Use release builds for stable permission testing

#### 4. AppDelegate Singleton Pattern
```swift
// In AppDelegate
weak static var shared: AppDelegate?

func applicationDidFinishLaunching(_ notification: Notification) {
    AppDelegate.shared = self
}

// Usage in services
guard let delegate = AppDelegate.shared else { return }
```

#### 5. Debug Logging for CGEventTap
```swift
// Console.app has privacy restrictions
// Use file-based logging instead
class DebugLogger {
    static func log(_ message: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AltSwitch_debug.log")
        // Write to file...
    }
}
```

#### 6. Settings-Aware Interception
```swift
// Check if shortcut is actually registered before intercepting
let cmdTabEnabled = KeyboardShortcuts.getShortcut(for: .cmdTabShowHide) != nil
if cmdTabEnabled {
    // Intercept and consume event
    return nil
}
// Pass through if not enabled
return Unmanaged.passUnretained(event)
```

### Known Issues with Hold-and-Cycle

**Problem**: Implementing hold-and-cycle behavior breaks basic interception
- Attempted approach: Pass through subsequent Tab presses while modifier held
- Result: Breaks all interception, neither first nor subsequent presses work
- Root cause: Complex state management between CGEventTap and app event handling

**Workaround**: Currently all Tab presses are intercepted and consumed
- Each Tab press shows/hides the window
- Cycling must be done with arrow keys or mouse

**Future Solution Ideas**:
1. Use separate event monitor for cycling mode
2. Implement two-phase interception with different handlers
3. Let KeyboardShortcuts handle cycling, CGEventTap only for activation

## Troubleshooting Guide

### CGEventTap Not Working

**Symptoms**: Alt+Tab/Cmd+Tab not being intercepted
1. Check ~/Documents/AltSwitch_debug.log for event tap status
2. Verify both Accessibility and Input Monitoring permissions granted
3. Ensure event tap creation succeeded (check for "CGEventTap creation attempt" in log)
4. Verify shortcuts are registered (check UserDefaults for KeyboardShortcuts_altTabShowHide)

**Debug Build Permission Issues**:
```bash
# Reset permissions and re-grant
tccutil reset All com.thoughtsun.AltSwitch
# Then manually grant in System Settings > Privacy & Security
```

**Release Build Testing**:
```bash
# Build release version for stable signature
xcodebuild -scheme AltSwitch -configuration Release build
# Permissions will persist across launches
```

### Hotkey Registration Issues
**Problem**: Hotkey registration fails with "already in use" error
```swift
// Solution: Use HotkeyErrorHandler for automatic conflict resolution
let errorHandler = HotkeyErrorHandler()
if let alternative = await errorHandler.registerWithConflictResolution(combo) { ... }
```

**Problem**: Hotkey not responding after registration
```swift
// Check if KeyboardShortcuts.Name is properly defined
extension KeyboardShortcuts.Name {
    static let myHotkey = Self("myHotkey", default: .init(.space, modifiers: [.command]))
}
```

**Problem**: Performance issues with hotkey registration
```swift
// Use performance tests to validate timing
xcodebuild test -scheme AltSwitch -only-testing:AltSwitchTests/HotkeyPerformanceTests
```

### Configuration Migration Issues
**Problem**: Settings lost after app update
```swift
// Check migration logs and restore from backup
let migrator = SettingsMigrator()
let backups = try await migrator.listBackups()
let restored = try await migrator.restoreFromBackup(path: backups.first!.path)
```

**Problem**: Invalid configuration format
```swift
// Validate configuration and show user-friendly errors
let config = try Configuration.fromYAML(yaml)
if !config.isValid {
    print("Validation errors: \(config.validationErrors)")
}
```

### Accessibility Issues
**Problem**: VoiceOver not announcing hotkey changes
```swift
// Ensure AccessibilityAnnouncer is properly configured
let announcer = AccessibilityAnnouncer()
announcer.settings.announceHotkeyChanges = true
announcer.announceHotkeyChange(from: oldCombo, to: newCombo)
```

### Performance Benchmarks
- **Hotkey Registration**: < 100ms (measured by HotkeyPerformanceTests)
- **Configuration Loading**: < 50ms for typical settings
- **Settings Migration**: < 200ms for version upgrades
- **Memory Usage**: < 2MB increase during operations
- **Error Recovery**: < 50ms for conflict resolution

### Testing Methodology
1. **Unit Tests**: Swift Testing framework for all business logic
2. **Performance Tests**: Automated benchmarks for timing requirements
3. **Integration Tests**: End-to-end scenarios with real KeyboardShortcuts
4. **Contract Tests**: Protocol compliance verification
5. **Accessibility Tests**: VoiceOver and assistive technology validation

### Error Handling Coverage
- Hotkey registration conflicts
- Invalid key combinations
- System permission denials
- Configuration corruption
- Migration failures
- Network connectivity issues (for updates)

## Specialized Agents

This repository uses specialized Claude Code agents for different types of work. See `AGENTS.md` for complete details.

### Available Agents
- **swift-test-engineer** - Design, implement, and debug automated tests for Swift/SwiftUI macOS applications
- **swift-code-reviewer** - Pragmatic code reviews focusing on correctness, maintainability, and CLAUDE.md alignment
- **swift-architect** - High-level architectural decisions, system design, API boundaries (future)
- **swift-engineer** - Fast execution of well-defined implementation tasks (future)
- **swift-principal-engineer** - Complex features requiring both depth and architectural judgment (future)

### When to Use Agents
Refer to `AGENTS.md` for:
- Detailed agent descriptions and capabilities
- When to pick which agent
- How to delegate tasks effectively
- Agent definitions in `.claude/agents/`

## MCP Server Integration

The project uses two MCP servers for enhanced functionality:

### 1. Context7 - Documentation Lookup
Use context7 for Apple API documentation and code examples:

**Available Tools**:
- `mcp__context7__resolve-library-id` - Find Context7 library ID for a package
- `mcp__context7__get-library-docs` - Fetch up-to-date documentation

**When to Use**:
1. Before implementing new APIs (NSWorkspace, CGWindow, AXUIElement)
2. When encountering errors or migration issues
3. For best practices with SwiftUI modifiers
4. During code review to verify API usage

**Example Usage**:
```swift
// Resolve library ID first
mcp__context7__resolve-library-id("SwiftUI")

// Then fetch docs using the resolved ID
mcp__context7__get-library-docs(context7CompatibleLibraryID: "/apple/swiftui", topic: "window management")
```

### 2. Beads - Issue Tracking
Use beads for task and issue management:

**Available Tools**:
- `mcp__plugin_beads_beads__list` - List all issues with filters
- `mcp__plugin_beads_beads__show` - Show detailed issue information
- `mcp__plugin_beads_beads__create` - Create new issues
- `mcp__plugin_beads_beads__update` - Update issue status/priority
- `mcp__plugin_beads_beads__ready` - Find tasks ready to work on
- `mcp__plugin_beads_beads__blocked` - Get blocked issues

**When to Use**:
- Track bugs, features, tasks, and epics
- Manage dependencies between tasks
- Check what's ready to work on
- Update task status during development

**Example Workflow**:
```bash
# Find ready tasks
mcp__plugin_beads_beads__ready(limit: 10)

# Show task details
mcp__plugin_beads_beads__show(issue_id: "TASK-123")

# Update status when starting work
mcp__plugin_beads_beads__update(issue_id: "TASK-123", status: "in_progress")

# Close when done
mcp__plugin_beads_beads__close(issue_id: "TASK-123", reason: "Completed")
```

## Documentation Resources

### Official Apple Documentation to Reference
- [Human Interface Guidelines - macOS](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SwiftUI for macOS](https://developer.apple.com/documentation/swiftui)
- [Accessibility for macOS](https://developer.apple.com/documentation/accessibility)
- [Window Management](https://developer.apple.com/documentation/appkit/windows_panels_and_screens)

Use MCP tools to fetch latest versions of these docs when implementing features.

## Private APIs & Space Switching

**CRITICAL**: AltSwitch uses 9 private macOS APIs for space switching and window management. These are essential for the app's core functionality as macOS has NO PUBLIC APIs for switching between spaces.

### Key Private APIs Documentation
Comprehensive documentation is available in the following files:
- **PRIVATE_APIS_README.md** - Start here for overview and navigation guide
- **PRIVATE_APIS_AUDIT.md** - Complete list of all 9 private APIs with technical details
- **PRIVATE_APIS_ARCHITECTURE.md** - System design and data flow
- **PRIVATE_APIS_DETAILED.md** - Deep technical documentation
- **PRIVATE_APIS_FILE_LOCATIONS.md** - Cross-reference guide with line numbers

### The 9 Private APIs (Quick Reference)
**SkyLight Framework (7 APIs)**:
1. `CGSMainConnectionID()` - CoreGraphics server connection
2. `CGSCopyManagedDisplaySpaces()` - Enumerate displays and spaces
3. `CGSManagedDisplayGetCurrentSpace()` - Get active space
4. `CGSCopySpacesForWindows()` - Find spaces containing windows
5. `CGSCopyWindowsWithOptionsAndTags()` - Get windows in spaces
6. `CGSCopyActiveMenuBarDisplayIdentifier()` - Get display with active menu bar
7. `_SLPSSetFrontProcessWithOptions()` - **CRITICAL: Activates windows and switches spaces**

**ApplicationServices Framework (2 APIs)**:
8. `GetProcessForPID()` - Convert PID to ProcessSerialNumber
9. `SLPSPostEventRecordTo()` - Send low-level messages to make windows key

### Implementation Locations
- **Declarations**: `AltSwitch/Services/Platform/Spaces/SkyLight.framework.swift`
- **Declarations**: `AltSwitch/Services/Platform/Spaces/ApplicationServices.HIServices.framework.swift`
- **Usage**: `AltSwitch/Services/AppManagement/AppSwitcher.swift` (window activation)
- **Usage**: `AltSwitch/Services/Platform/Spaces/Spaces.swift` (space enumeration)
- **Usage**: `AltSwitch/Services/Platform/Spaces/CGWindowID+Spaces.swift` (window-to-space mapping)

### Consequences of Using Private APIs
- ✓ Enables features impossible with public APIs
- ✓ Works correctly with Mission Control and spaces
- ✗ May break in future macOS versions
- ✗ Requires non-sandboxed app
- ✗ Cannot distribute via Mac App Store
- ✗ Requires both Accessibility AND Input Monitoring permissions

### When Working with Private APIs
1. **Never modify the private API declarations** without verifying against source projects (AltTab, Hammerspoon)
2. **Always check PRIVATE_APIS_ARCHITECTURE.md** before changing activation flow
3. **Test on multiple macOS versions** when making changes
4. **Verify permissions** are correctly requested in entitlements

## Window Discovery Package

AltSwitch includes a comprehensive Window Discovery Package architecture (currently being extracted into a separate package). Full documentation is available:

- **docs/window-discovery-package/INDEX.md** - Complete index and navigation
- **docs/window-discovery-package.md** - Main 61KB architecture document
- **docs/window-discovery-package/IMPLEMENTATION_GUIDE.md** - Step-by-step workflow

### Six-Phase Implementation Plan
1. **Phase 1**: Package Creation (12 tasks)
2. **Phase 2**: Provider Layer (16 tasks) - AX and CG window providers
3. **Phase 3**: Discovery Layer (14 tasks) - Window discovery strategies
4. **Phase 4**: Caching Layer (7 tasks, optional) - Performance optimization
5. **Phase 5**: CLI Tool (13 tasks) - Standalone debugging tool
6. **Phase 6**: AltSwitch Integration (17 tasks) - Integration with main app

Each phase has detailed spec.md and tasks.md files with atomic, time-estimated tasks suitable for junior developers.

## Change Management & OpenSpec

This project uses OpenSpec for structured change proposals. See `AGENTS.md` for complete details.

### When to Create a Change Proposal
Create proposals via `openspec/` when:
- Introducing new capabilities or features
- Making breaking changes
- Significant architecture shifts
- Major performance or security work
- Request sounds ambiguous and needs authoritative spec

### OpenSpec Structure
```
openspec/
├── AGENTS.md           # Change proposal workflow
├── project.md          # Project metadata
└── changes/
    └── [change-name]/
        ├── proposal.md # Change description
        ├── tasks.md    # Implementation tasks
        └── specs/      # Detailed specifications
```

### Creating a Proposal
Refer to `openspec/AGENTS.md` for the complete workflow on creating and applying change proposals.

## Current Development Phase
Refer to PLAN.md Phase 1: Foundation. Focus on implementing core window management before UI polish.

## Preferences Architecture
The app uses a Browserino-inspired preferences architecture with modular tab-based organization:

### Key Principles
- **File Separation**: Each tab is a separate file for better maintainability
- **Component Reuse**: Shared components live in `Components/` subdirectory
- **Consistent Sizing**: Fixed 600×400pt window for all tabs
- **Modern SwiftUI**: Uses `.formStyle(.grouped)` and proper environment objects

### Migration Notes
- Old `SettingsView.swift` has been backed up as `SettingsView.swift.backup`
- App entry point updated to use `PreferencesView` instead of `SettingsView`
- All existing `@AppStorage` keys preserved for backwards compatibility
- NSTableView styling extension added for clean table backgrounds

### Testing Preferences
```bash
# Build and test preferences interface
xcodebuild build -scheme AltSwitch -configuration Debug

# Manual testing checklist:
# 1. Open preferences from menu bar
# 2. Test each tab switches correctly  
# 3. Verify all settings controls work
# 4. Confirm settings persist after restart
```
