# CLI Manual Verification Test

## Overview

`test-cli-manual.sh` is an automated test script that verifies the MacWindowDiscovery CLI is working correctly by:
1. Opening test applications automatically
2. Running CLI commands
3. Showing detected windows
4. Asking you to verify results
5. Tracking pass/fail
6. Showing summary

## Usage

```bash
cd /Users/jack/Code/withakay/mac-apps/altswitch/packages/MacWindowDiscovery
./test-cli-manual.sh
```

## What the Script Does

### Automatic Actions
- ✓ Builds the CLI (`swift build`)
- ✓ Opens TextEdit (3 windows)
- ✓ Opens Safari, Notes, Calculator
- ✓ Opens Finder windows (Desktop, Documents, Downloads)
- ✓ Hides Calculator window
- ✓ Minimizes Safari window
- ✓ Runs CLI commands with various options
- ✓ Cleans up all test apps

### Manual Actions (You)
- Verify the CLI output shows correct windows
- Answer [y/n] for each test
- Press [Enter] to advance through tests

## Tests Performed

1. **Pre-flight Check** - Version and permissions
2. **Single Window** - TextEdit with 1 window
3. **Multi-Window** - TextEdit with 3 windows
4. **Multiple Apps** - Safari, Notes, Calculator, Finder, TextEdit
5. **Finder Multi-Window** - 3 Finder windows with different folders
6. **JSON Output** - Validate JSON format
7. **App-Specific Query** - Safari-only windows
8. **Hidden Window** - Calculator hidden with ⌘H
9. **Minimized Window** - Safari window minimized
10. **Size Filtering** - Filter by window dimensions

## Expected Results

All tests should **PASS** if:
- ✓ Accessibility permissions are granted
- ✓ CLI detects all opened windows
- ✓ Window metadata is accurate (title, bounds, app)
- ✓ Filters work correctly (hidden, minimized, size)
- ✓ Output formats work (table, JSON, compact)

## Example Output

```
═══════════════════════════════════════════════
TEST 3: Multi-Window Detection (TextEdit)
═══════════════════════════════════════════════

➜ Opening 2 more TextEdit windows...

Press [Enter] to continue...

RUNNING: .build/debug/mac-window-discovery list --app com.apple.TextEdit --format table

┌─────────┬──────────────┬──────────┬──────────────────┐
│ ID      │ Title        │ App      │ Bounds           │
├─────────┼──────────────┼──────────┼──────────────────┤
│ 12345   │ Untitled     │ TextEdit │ (100,100,600,400)│
│ 12346   │ Untitled 2   │ TextEdit │ (120,120,600,400)│
│ 12347   │ Untitled 3   │ TextEdit │ (140,140,600,400)│
└─────────┴──────────────┴──────────┴──────────────────┘

VERIFY:
  1. See 3 TextEdit windows
  2. Each has different window ID
  3. Titles may be Untitled, Untitled 2, Untitled 3

Did this test PASS? [y/n]: y
✓ Test passed: Multi-Window Detection
```

## Final Summary

```
═══════════════════════════════════════════════
TEST SUMMARY
═══════════════════════════════════════════════

Total Tests: 10
Passed: 10 ✓
Failed: 0 ✗

✓ ALL TESTS PASSED! 🎉

The MacWindowDiscovery CLI is working correctly.

Pass Rate: 100%
```

## Troubleshooting

### Script Fails to Build CLI
```bash
# Build manually first
swift build

# Check if binary exists
ls -la .build/debug/mac-window-discovery
```

### Permission Errors
```bash
# Check accessibility permissions
./test-cli-manual.sh
# If "Accessibility permission: NOT GRANTED", grant in:
# System Settings → Privacy & Security → Accessibility
```

### Apps Don't Open
- Ensure apps exist: TextEdit, Safari, Notes, Calculator, Finder (all built-in)
- Check if apps are already running (script handles this)

### Wrong Window Count
- Some apps may have existing windows open
- Close all windows before running script
- Script tries to clean up at the end

## Duration

**Estimated Time**: 5-10 minutes
- Mostly automated
- Pauses for you to review output and answer y/n

## Clean Exit

Press `Ctrl+C` to exit early. The script will leave apps open if interrupted.

To manually clean up:
```bash
osascript -e 'quit app "TextEdit"'
osascript -e 'quit app "Safari"'
osascript -e 'quit app "Notes"'
osascript -e 'quit app "Calculator"'
osascript -e 'tell application "Finder" to close every window'
```

## Notes

- Script uses `osascript` (AppleScript) to control apps
- All actions are non-destructive (no data loss)
- Creates only empty TextEdit documents
- Safe to run multiple times
