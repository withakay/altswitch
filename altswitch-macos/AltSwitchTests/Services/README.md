# AppDiscoveryService Test Suite

## Overview

This directory contains comprehensive integration tests for `AppDiscoveryService` designed to protect against regressions during the planned refactoring described in `docs/plan.md`.

## Test Files

### AppDiscoveryServiceTests.swift
Core integration tests covering all three required test suites:

#### Test Suite 1: Window Discovery Accuracy
- **test_discoversAllStandardWindows**: Verifies all running apps are discovered with valid properties
- **test_filtersUtilityWindows**: Confirms utility windows (inspector, popups, etc.) are filtered out
- **test_handlesAppsWithNoWindows**: Ensures apps without windows (menu bar apps) are handled correctly
- **test_identifiesFocusedWindows**: Validates focus state tracking for the frontmost app
- **test_discoversWindowsAcrossSpaces**: Tests window discovery across multiple macOS Spaces

#### Test Suite 2: Individual Window Mode
- **test_individualModeCreatesSeparateAppInfo**: Verifies each window gets its own AppInfo entry
- **test_windowTitlesExtractedCorrectly**: Confirms window titles are properly extracted from AX API
- **test_focusStateAccurateInIndividualMode**: Validates focus tracking in individual window mode
- **test_individualModeFiltersToStandardWindows**: Ensures only standard windows appear in individual mode

#### Test Suite 3: Event-Driven Updates
- **test_initializesWithEventDrivenMode**: Verifies event mode initialization when permissions granted
- **test_cacheTTLInNonEventMode**: Tests TTL-based caching behavior (500ms cache)
- **test_separateCacheForModes**: Confirms separate caches for standard vs individual mode
- **test_refreshWindowsForSpecificApp**: Validates per-app window refresh functionality

#### Performance Tests
- **test_discoveryPerformance**: Discovery must complete within 500ms
- **test_individualModePerformance**: Individual mode must complete within 700ms

#### Edge Cases
- **test_handlesInvalidPIDs**: Ensures invalid process identifiers are handled
- **test_filtersSystemProcesses**: Confirms system processes are filtered (Dock, WindowManager, etc.)
- **test_excludesOwnApp**: Verifies AltSwitch itself is excluded from results
- **test_handlesInvisibleScreenWindows**: Tests window-screen intersection logic

### AppDiscoveryEventTests.swift
Event-driven behavior and AX observer tests:

#### Event-Driven Behavior
- App launch detection tests
- App termination detection tests
- Window creation detection via AXObserver
- Window destruction detection via AXObserver
- Focused window change detection
- Cache behavior validation

#### AX Observer Integration
- AX observer registration for eligible apps
- Observer cleanup on app termination
- Rapid window update handling without flooding

#### Performance Under Load
- Concurrent request handling (50 parallel requests <2s)
- Memory stability under repeated calls (100 iterations)

### AppDiscoveryServiceMocks.swift
Test fixtures and mock implementations:

- **MockWindowFactory**: Create test WindowInfo instances
- **MockAppFactory**: Create test AppInfo instances
- **MockAppDiscoveryService**: Isolated mock implementation with call tracking
- **MockCGWindowData**: Create mock CGWindow dictionary data

## Test Isolation

### Integration vs Unit Tests
These are **integration tests** that exercise the real `AppDiscoveryService` against the actual macOS window APIs. They:
- Call real NSWorkspace APIs
- Use real CGWindow APIs
- Require actual running applications
- May require Accessibility permissions

### Hermetic Testing Challenges
Full hermeticity is not possible due to system dependencies:

1. **NSWorkspace**: Cannot mock running application state
2. **CGWindowListCopyWindowInfo**: System-level window list access
3. **AXUIElement**: Accessibility API requires system permissions
4. **Spaces API**: Private APIs for Space information

### Mock Usage
Mocks are provided for:
- Isolated unit testing of service consumers
- Testing error conditions
- Performance benchmarking without system variability

## Running the Tests

### Run All AppDiscoveryService Tests
```bash
xcodebuild test -scheme AltSwitch -only-testing:AltSwitchTests/WindowDiscoveryAccuracyTests
xcodebuild test -scheme AltSwitch -only-testing:AltSwitchTests/IndividualWindowModeTests
xcodebuild test -scheme AltSwitch -only-testing:AltSwitchTests/EventDrivenUpdateTests
```

### Run Specific Test
```bash
xcodebuild test -scheme AltSwitch \
  -only-testing:AltSwitchTests/WindowDiscoveryAccuracyTests/test_discoversAllStandardWindows
```

### Run All Service Tests
```bash
xcodebuild test -scheme AltSwitch -only-testing:AltSwitchTests/AppDiscoveryServicePerformanceTests
xcodebuild test -scheme AltSwitch -only-testing:AltSwitchTests/AppDiscoveryEventTests
```

## Test Coverage

### What IS Covered
- ✅ Window discovery accuracy across all running apps
- ✅ Utility window filtering logic
- ✅ Apps with/without windows
- ✅ Focus state tracking
- ✅ Space awareness (isOnAllSpaces, spaceIds)
- ✅ Individual window mode behavior
- ✅ Window title extraction from AX API
- ✅ Cache TTL behavior (500ms)
- ✅ Separate caches per mode
- ✅ Per-app window refresh
- ✅ System process filtering
- ✅ Performance budgets (500ms/700ms)
- ✅ Invalid PID handling
- ✅ Screen intersection logic

### What IS NOT Covered (Requires Manual Testing)
- ❌ **Real-time event detection**: Cannot programmatically launch/terminate apps in tests
- ❌ **AX observer callbacks**: Cannot trigger actual window creation/destruction events
- ❌ **Multi-Space behavior**: Requires manual Space setup and app arrangement
- ❌ **Permission state changes**: Cannot grant/revoke Accessibility permissions in tests
- ❌ **Brute-force AX window discovery**: Private API behavior varies by app
- ❌ **Memory usage over time**: Requires Instruments profiling
- ❌ **Icon caching behavior**: NSImage caching is opaque

## Test Limitations and Assumptions

### System State Dependencies
Tests assume:
- At least one regular app is running (Safari, Finder, etc.)
- System is not in Safe Mode
- Accessibility permissions may or may not be granted (tests adapt)
- At least one screen is active

### Timing Assumptions
Performance tests use these budgets:
- Discovery: 500ms (typical: 50-200ms)
- Individual mode: 700ms (typical: 100-300ms)
- Cache hit: <10ms
- Refresh: <100ms

### Flakiness Mitigation
- Tests use `.serialized` to avoid parallel execution issues
- Performance tests allow headroom (2x typical values)
- Event tests check for permissions before running
- Cache tests explicitly wait for TTL expiry

## Coverage Metrics

### Baseline Coverage (Pre-Refactoring)
Expected coverage for AppDiscoveryService:

- **Line Coverage**: ~60% (limited by system API mocking)
- **Branch Coverage**: ~70% (error paths covered via mocks)
- **Function Coverage**: ~85% (most public methods exercised)

### Uncoverable Code
These areas cannot be tested automatically:
- Private AX APIs behavior edge cases
- NSWorkspace notification handlers (require real app lifecycle)
- AXObserver callback registration (requires real AX events)
- Icon cache implementation details (NSCache is opaque)

## Refactoring Guidelines

When refactoring AppDiscoveryService:

1. **Run tests BEFORE changes**: Establish baseline pass rate
2. **Run tests AFTER each refactor**: Verify no regressions
3. **Update tests if behavior changes**: Document intentional changes
4. **Do NOT modify tests during refactoring**: Tests protect behavior

### Expected Test Stability
- **Window Discovery**: Stable (depends on running apps)
- **Individual Mode**: Stable (pure logic)
- **Performance**: May vary ±20% based on system load
- **Event Tests**: Sensitive to permissions state

## Debugging Test Failures

### Test Failure: "Should discover at least one running app"
**Cause**: No regular apps running (only system processes)
**Fix**: Launch Safari, Finder, or any regular application

### Test Failure: Performance budget exceeded
**Cause**: System under load or slow disk
**Fix**: Close background apps, retry, or increase budget if consistently slow

### Test Failure: "Skipping event test - no accessibility permissions"
**Cause**: Accessibility permissions not granted
**Fix**: Expected behavior - test is skipped gracefully

### Test Failure: Focus state incorrect
**Cause**: Window focus changed during test execution
**Fix**: Avoid switching apps during test run

## Future Enhancements

### Potential Additions
1. **App Lifecycle Simulation**: Launch/terminate test apps programmatically
2. **AX Event Injection**: Mock AXObserver notifications
3. **Space API Mocking**: Stub private Spaces API responses
4. **Performance Regression Tracking**: Store baseline metrics, alert on degradation
5. **Coverage Visualization**: Generate HTML coverage reports

### Test Improvements
- Add parameterized tests for various window sizes
- Test tabbed window detection when implemented
- Add stress tests for 100+ running apps
- Test window discovery in fullscreen mode

## Related Documentation

- **docs/plan.md**: Refactoring plan this test suite protects against
- **CLAUDE.md**: Project-wide testing guidelines
- **AppDiscoveryService.swift**: Implementation under test

## Test Ownership

These tests are **regression protection** for the refactoring work. Any changes to AppDiscoveryService behavior MUST be reflected in these tests or explicitly documented as intentional behavior changes.