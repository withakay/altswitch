# Provider Integration Tests

These tests verify providers work with real system APIs. Run manually in development.

## Prerequisites
- [ ] Xcode with macOS app scheme
- [ ] Accessibility permissions granted
- [ ] Multiple apps running (Safari, Finder, Terminal, etc.)

## CGWindowProvider Tests

### Test 1: Basic Window Capture
**Steps:**
1. Open Safari with 2-3 windows
2. Run: `let provider = CGWindowProvider(); let windows = try provider.captureWindowList()`
3. Print window count

**Expected:**
- [ ] Returns > 10 windows (system + test apps)
- [ ] Each window has id, pid, bounds
- [ ] No crashes or errors

### Test 2: Performance
**Steps:**
1. Have 50+ windows open (multiple apps)
2. Measure: `let start = Date(); try provider.captureWindowList(); let elapsed = Date().timeIntervalSince(start)`

**Expected:**
- [ ] Completes in < 50ms
- [ ] No memory leaks

## AXWindowProvider Tests

### Test 3: Window State Enrichment
**Steps:**
1. Open Safari with 1 window
2. Minimize the window
3. Get Safari's PID
4. Run: `let provider = AXWindowProvider(); let lookup = provider.buildWindowLookup(for: safariPID, bundleIdentifier: "com.apple.Safari")`
5. Check `lookup[windowID]?.isMinimized`

**Expected:**
- [ ] Lookup contains Safari windows
- [ ] Minimized state correctly detected
- [ ] Window titles present

### Test 4: No Permissions Handling
**Steps:**
1. Revoke accessibility permissions
2. Run buildWindowLookup
3. Restore permissions

**Expected:**
- [ ] Returns empty lookup (no crash)
- [ ] Prints warning message
- [ ] Gracefully degrades

## NSWorkspaceProvider Tests

### Test 5: Running Apps
**Steps:**
1. Open Safari, Finder, Terminal
2. Run: `let provider = NSWorkspaceProvider(); await provider.runningApplications()`

**Expected:**
- [ ] Returns 20+ apps
- [ ] Includes Safari, Finder, Terminal
- [ ] Each has bundle ID and name

## SpacesAPI Tests

### Test 6: Space Detection
**Steps:**
1. Create 2+ Spaces (Mission Control)
2. Move Safari to Space 2
3. Get Safari window ID
4. Run: `let spaces = SpacesAPI.getWindowSpaces(windowID)`

**Expected:**
- [ ] Returns non-empty array (if API available)
- [ ] Returns empty array gracefully if unavailable
- [ ] No crashes

### Test 7: Active Space
**Steps:**
1. Switch to Space 2
2. Run: `let activeSpace = SpacesAPI.activeSpaceID()`

**Expected:**
- [ ] Returns positive integer (if API available)
- [ ] Returns 0 if unavailable
- [ ] No crashes

## Performance Tests

### Test 8: Combined Performance
**Steps:**
1. Have 50+ windows, 30+ apps
2. Time all providers together

**Expected:**
- [ ] CGWindowProvider: < 50ms
- [ ] AXWindowProvider: < 200ms for 10 apps
- [ ] NSWorkspaceProvider: < 10ms
- [ ] Total: < 300ms

## Sign-off

- [ ] All tests passed
- [ ] No crashes observed
- [ ] Performance meets requirements
- [ ] Ready for Phase 3

**Tester:** _______________
**Date:** _______________
