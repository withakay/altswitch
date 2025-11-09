# Window Filtering Specification

This document describes the complete filtering and validation pipeline for window discovery in MacWindowDiscovery.

## Overview

Window discovery operates in 4 stages:

1. **Validation** - Basic data integrity checks
2. **Filtering** - Policy-based inclusion/exclusion
3. **Building** - Construct WindowInfo objects with title resolution
4. **Post-Processing** - Remove duplicate/invalid windows per app

---

## Stage 1: Validation (WindowValidator)

Basic validation ensures window data from CGWindowList is structurally valid.

### Rules

#### Required Fields
- **Window ID** (`kCGWindowNumber`)
  - Must exist
  - Must be > 0
  - Type: `CGWindowID` (UInt32)

- **Process ID** (`kCGWindowOwnerPID`)
  - Must exist
  - Must be > 0
  - Type: `pid_t` (Int32)

- **Bounds** (`kCGWindowBounds`)
  - Must exist
  - Must contain Width and Height keys
  - Width must be > 0
  - Height must be > 0
  - Type: Dictionary `[String: CGFloat]`

#### Optional Fields with Validation

- **Alpha** (`kCGWindowAlpha`)
  - If present, must be >= 0.0 and <= 1.0
  - Type: Double

- **Layer** (`kCGWindowLayer`)
  - If present, must be >= -1000 and <= 1000
  - Type: Int

### Outcome
Windows failing validation are **immediately rejected** and never reach filtering stage.

---

## Stage 2: Filtering (WindowFilterPolicy)

Policy-based filtering applies user-configurable rules to determine which windows to include.

### 2.1 Size Filters

#### Minimum Size (configurable)
- Default: 100x50 pixels
- Rejects windows smaller than configured minimum
- Applied to all windows regardless of type

### 2.2 Visual Filters

#### Minimum Alpha (configurable)
- Default: 0.9 (90% opacity)
- Rejects windows with alpha < configured minimum
- Prevents inclusion of nearly-transparent UI elements

#### Layer Filter (configurable)
- Default: Layer 0 only (`normalLayerOnly = true`)
- Layer 0 = normal application windows
- Other layers = overlays, HUD elements, system UI
- When enabled, rejects windows with layer != 0

### 2.3 Window State Filters

#### Hidden Windows (configurable)
- Default: Exclude (`includeHidden = false`)
- Requires AX metadata to determine hidden state
- Windows without AX metadata pass this filter

#### Minimized Windows (configurable)
- Default: Include (`includeMinimized = true`)
- Requires AX metadata to determine minimized state
- Windows without AX metadata pass this filter

### 2.4 Application Filters

#### Bundle Identifier Whitelist (configurable)
- Default: None (nil)
- When set, **only** windows from whitelisted bundle IDs are included
- All other windows are rejected

#### Bundle Identifier Blacklist (configurable)
- Default: Empty set
- Windows from blacklisted bundle IDs are rejected
- Applied after whitelist check

#### System Process Filter (configurable)
- Default: Enabled (`excludeSystemProcesses = true`)
- Rejects windows from known system processes and menu bar apps

##### System Process Prefixes
```
com.apple.controlcenter
com.apple.systemuiserver
com.apple.dock
com.apple.notificationcenterui
com.apple.WindowManager
com.apple.loginwindow
com.apple.AuthenticationServices      # AutoFill panels
com.apple.AutoFillPanelService        # AutoFill service
com.apple.SafariPlatformSupport       # Safari AutoFill helper
com.apple.LocalAuthentication         # LocalAuthenticationRemoteService
com.apple.UserNotificationCenter      # UserNotificationCenter
com.apple.appkit.xpc                  # Open and Save Panel Service
com.apple.Spotlight                   # Spotlight window
```

##### Menu Bar Apps (Exact Match)
```
com.jordanbaird.Ice                   # Ice menubar manager
com.browserino.Browserino             # Browserino browser switcher
```

### 2.5 Space Filters

#### Include Inactive Spaces (configurable)
- Default: Include (`includeInactiveSpaces = true`)
- When disabled, only windows on active spaces are included
- Active spaces determined per-display (multi-monitor aware)
- Requires space information to be available

**Implementation:**
- Checks if window's spaceIDs intersect with active space IDs
- Windows with empty spaceIDs are **rejected** when this filter is active

### 2.6 Title Requirements (configurable)

#### Require Title (configurable)
- Default: Disabled (`requireTitle = false`)
- When enabled, rejects windows without AX-readable titles
- Only considers AX titles (not cached or fallback titles)

### 2.7 Accessibility Metadata Requirements (configurable)

#### Require Proper Subrole (configurable)
- Default: Enabled (`requireProperSubrole = true`)
- Validates windows have proper AX window type

##### Valid Subroles
- `AXStandardWindow` - Normal application windows
- `AXDialog` - Dialog boxes

##### Filter Logic
For windows when `requireProperSubrole = true`:

**Case 1: Has proper subrole**
- Window has `subrole` field
- Subrole is `AXStandardWindow` or `AXDialog`
- **Action**: Include

**Case 2: No proper subrole, but on real space**
- Window has `subrole == nil` OR subrole is not valid
- Window has non-empty `spaceIDs` (exists on a real space)
- **Additional requirement**: Window must be >= 800x500 pixels
- **Rationale**: Windows on inactive spaces lack AX metadata, but are legitimate. Larger size requirement filters out auxiliary windows (download bars, settings panels, tool palettes)
- **Action**: Include if size requirement met

**Case 3: No proper subrole, not on real space**
- Window has `subrole == nil` OR subrole is not valid
- Window has empty `spaceIDs`
- **Action**: Reject (fake/system window)

### Outcome
Windows passing all active filters proceed to building stage.

---

## Stage 3: Building (WindowInfoBuilder)

Constructs complete WindowInfo objects from multiple data sources.

### 3.1 Title Resolution

Title resolution follows a strict fallback chain with caching:

#### Resolution Order
1. **AX Title** (from Accessibility API)
   - Most accurate source
   - Only available for windows on active spaces
   - **Action**: Use and cache for future lookups
   - Cache key: Window ID

2. **Cached Title** (from WindowTitleCache)
   - Retrieved from FIFO cache (100 entry capacity)
   - Used when AX title not available (window on inactive space)
   - Populated by previous AX title reads
   - **Action**: Use cached value

3. **Blank Title**
   - If neither AX nor cached title available
   - **Action**: Set title to empty string `""`

#### Cache Behavior
- **Cache Type**: FIFO (First In, First Out)
- **Capacity**: 100 entries
- **Eviction**: Oldest entry removed when capacity exceeded
- **Update**: New entry replaces existing entry for same window ID (moves to end of queue)
- **Invalidation**: Cache cleared on space changes (via event monitoring)

### 3.2 Other Fields

All other fields are resolved using standard fallback chains:
- **Application metadata**: From NSWorkspace (AppInfo)
- **Window state**: From AX API (AXWindowInfo)
- **Bounds, alpha, layer**: From CG API (CGWindowList)
- **Space information**: From Spaces private API

### Outcome
All validated and filtered windows become WindowInfo objects.

---

## Stage 4: Post-Processing (WindowDiscoveryEngine)

Final filtering step removes auxiliary windows when app has proper main windows.

### 4.1 Duplicate Window Removal

Applied only when `requireProperSubrole = true`.

#### Algorithm

**For each application (grouped by process ID):**

1. **Identify valid windows**
   - Check if app has ANY windows with proper subrole
   - Valid subroles: `AXStandardWindow`, `AXDialog`

2. **Case A: App has windows with proper subrole**
   - Keep windows that have proper subrole **OR** are on real spaces
   - This preserves main windows AND windows on inactive spaces
   - Rejects auxiliary windows (settings, panels) without AX metadata and not on spaces

3. **Case B: App has NO windows with proper subrole**
   - Keep ALL windows for this app
   - Prevents over-filtering apps with unusual window types

#### Rationale
- Apps often have multiple windows: main window, settings, floating palettes, download bars
- Main windows have proper AX subroles
- Auxiliary windows often lack proper AX metadata
- Windows on inactive spaces also lack AX metadata (API limitation)
- Using space information distinguishes legitimate windows from auxiliary windows

#### Examples

**Example 1: Safari with download panel**
- Main window: Has `AXStandardWindow` → Keep
- Download bar: No proper subrole, not on space → Reject
- Result: 1 window (main)

**Example 2: Zed on 2 spaces**
- Space 1 window: Has `AXStandardWindow` → Keep
- Space 2 window: No AX metadata (inactive space), but on space 2 → Keep
- Result: 2 windows (correct)

**Example 3: Utility app without AX support**
- All windows: No proper subroles
- Result: Keep all windows (don't over-filter)

### Outcome
Final window list ready for consumption.

---

## Configuration Options

### WindowDiscoveryOptions

All filters are configurable via `WindowDiscoveryOptions`:

```swift
WindowDiscoveryOptions(
    // Size filters
    minimumSize: CGSize(width: 100, height: 50),

    // Visual filters
    normalLayerOnly: Bool = true,
    minimumAlpha: Double = 0.9,

    // State filters
    includeHidden: Bool = false,
    includeMinimized: Bool = true,

    // Space filters
    includeInactiveSpaces: Bool = true,
    includeSpaceInfo: Bool = true,

    // Title filters
    requireTitle: Bool = false,
    requireProperSubrole: Bool = true,

    // App filters
    bundleIdentifierWhitelist: Set<String>? = nil,
    bundleIdentifierBlacklist: Set<String> = [],
    excludeSystemProcesses: Bool = true,

    // Performance
    useAccessibilityAPI: Bool = true
)
```

### Presets

#### `.default`
- Standard filtering for typical use cases
- Excludes hidden windows and system processes
- Includes minimized windows and inactive spaces
- Requires proper subrole (with space-based fallback)

#### `.fast`
- Minimal filtering, no AX API
- Fastest performance
- Less accurate filtering
- No title information

#### `.complete`
- Maximum inclusion
- Shows all windows including system UI
- Full metadata collection
- Useful for debugging

#### `.cli`
- Human-readable output
- Active space only
- Excludes system processes
- Optimized for command-line usage

---

## Edge Cases and Special Handling

### 1. Windows on Inactive Spaces
- **Problem**: AX API cannot read metadata for windows on inactive spaces
- **Solution**: Size-based heuristic (800x500 minimum) + space information
- **Trade-off**: May miss small legitimate windows on inactive spaces

### 2. Multi-Display Setups
- **Problem**: Multiple active spaces (one per display)
- **Solution**: `activeSpaceIDs()` returns all active spaces across displays
- **Behavior**: Window on ANY active space is considered "active"

### 3. Windows on All Spaces
- **Behavior**: Appear in all space arrays
- **Detection**: `spaceIDs.count > 1` → `isOnAllSpaces = true`

### 4. Apps Without AX Support
- **Problem**: Legacy apps or utilities may not support Accessibility API
- **Solution**: Post-processing keeps all windows if NONE have proper subroles
- **Trade-off**: May include auxiliary windows for these apps

### 5. Space Change Events
- **Problem**: Cached titles become stale when spaces change
- **Solution**: Event monitoring clears cache on `NSWorkspace.activeSpaceDidChangeNotification`
- **Behavior**: Next discovery refreshes titles for newly visible windows

### 6. Menu Bar Apps
- **Problem**: Show transient windows (settings, preferences)
- **Solution**: Explicit blacklist of known menu bar apps
- **Maintenance**: List must be updated as new apps are encountered

---

## Performance Characteristics

### Validation
- **Cost**: O(1) per window
- **Impact**: Minimal (simple field checks)

### Filtering
- **Cost**: O(1) per window
- **Impact**: Low (comparison operations)
- **Exception**: Bundle ID checks are O(n) for whitelist/blacklist size

### Building
- **Cost**: O(1) per window
- **Impact**: Moderate (includes cache lookups)
- **Note**: Actor-based cache has synchronization overhead

### Post-Processing
- **Cost**: O(n) where n = total windows
- **Impact**: Low (single pass grouping and filtering)

### Overall
- **Total**: O(n) where n = number of windows from CGWindowList
- **Typical**: 50-100ms for ~100 windows with AX API enabled
- **Fast mode**: 5-10ms without AX API

---

## Testing Recommendations

### Unit Tests
- Validate each filter rule independently
- Test edge cases (nil values, boundary conditions)
- Verify cache behavior (eviction, retrieval)

### Integration Tests
- Test complete pipeline with real window data
- Verify multi-space scenarios
- Test system process filtering
- Validate post-processing logic

### Manual Testing
- Test with various app types (browsers, utilities, menu bar apps)
- Verify behavior across space switches
- Check multi-display setups
- Test with apps open on multiple spaces

---

## Future Considerations

### Potential Improvements
1. **Machine learning-based classification**
   - Learn window patterns instead of hard-coded rules
   - Automatically detect auxiliary windows

2. **Configurable size thresholds per app**
   - Some apps legitimately have small windows
   - Per-app configuration could improve accuracy

3. **Window title caching to disk**
   - Persist cache across app restarts
   - Faster startup with pre-populated cache

4. **Dynamic system process detection**
   - Query system for menu bar apps
   - Reduce maintenance burden

5. **Better handling of picture-in-picture**
   - Detect PIP windows
   - Optional filtering

### Known Limitations
1. **Inactive space size heuristic**: May exclude small legitimate windows
2. **System process list**: Requires manual maintenance
3. **AX API dependency**: Cannot get full metadata without accessibility permissions
4. **Cache capacity**: Fixed at 100 entries (may need tuning for users with many windows)

---

## Version History

- **v1.0** (2025-11-01)
  - Initial specification
  - 4-stage pipeline: Validation → Filtering → Building → Post-Processing
  - FIFO title cache (100 entries)
  - Space-aware filtering with 800x500 minimum for windows without AX metadata
  - Event-driven cache invalidation
