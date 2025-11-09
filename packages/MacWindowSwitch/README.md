# MacWindowSwitch

A Swift package for activating macOS windows with cross-space and cross-display support.

## Overview

MacWindowSwitch provides reliable window activation capabilities on macOS, including the ability to switch to windows on different Spaces and displays. This functionality is essential for app switchers, window managers, and productivity tools.

**Key Features:**
- Activate windows by CGWindowID and process ID
- Automatic space switching when window is on a different Space
- Cross-display activation support
- Handles minimized, hidden, and unresponsive windows gracefully
- Clean async/await Swift API
- Zero external dependencies (core library)

## Status

✅ **Phase 0: Implementation Complete** - Ready for Manual Validation

Phase 0 (Faithful Port) implementation is complete. The package successfully extracts and encapsulates alt-tab-macos activation logic. Manual parity testing (Phases 0.6-0.7) is ready to begin.

**Location**: `/Users/jack/Code/withakay/mac-apps/altswitch/packages/MacWindowSwitch/`

## Requirements

- macOS 13.0+
- Swift 6.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add MacWindowSwitch to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/withakay/MacWindowSwitch.git", from: "0.1.0")
]
```

## Usage

```swift
import MacWindowSwitch

// Activate a window by ID and PID
try await WindowActivator.activate(
    windowID: 12345,
    processID: 67890
)
```

## Private APIs

⚠️ **Important**: This package uses private macOS APIs to achieve cross-space window activation, as macOS provides no public API for this functionality. While these APIs have been stable since macOS 10.12, they may change in future macOS versions.

**Implications:**
- Cannot be distributed via Mac App Store
- Requires non-sandboxed app
- Requires Accessibility permissions
- Supported on macOS 13.0+ (tested versions)

See [Documentation/PrivateAPIs.md](Documentation/PrivateAPIs.md) for details.

## License

GPL-3.0 License - matches the [alt-tab-macos](https://github.com/lwouis/alt-tab-macos) project from which the core activation logic is derived.

## Credits

Core window activation logic is based on [alt-tab-macos](https://github.com/lwouis/alt-tab-macos) by Louis Pontoise (@lwouis), which in turn builds upon work from the [Hammerspoon](https://www.hammerspoon.org/) project.

## Development

This package is being developed as part of the [AltSwitch](https://github.com/withakay/altswitch) project.
