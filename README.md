# AltSwitch

An alternative application switcher for macOS that combines the power of fuzzy search with traditional app switching. Inspired by application launchers like Alfred and Rofi, and built on techniques from AltTab and Yabai.

## Features

- 🔍 **Fuzzy Search**: Quickly find and switch to any open window by typing partial matches
- ⌨️ **Traditional Switching**: Tab through windows like the native macOS switcher
- ⚡ **High Performance**: Sub-100ms window discovery with intelligent caching
- 🎨 **Modern UI**: Clean, native SwiftUI interface with customizable appearance
- 🔧 **Highly Configurable**: Customize hotkeys, appearance, and behavior
- 🧪 **Well Tested**: Comprehensive test suite with 100+ tests

## Requirements

- macOS 13.0+
- Swift 6.0+
- Xcode 16.0+
- Accessibility permissions (required for window discovery)

## Installation

**TODO:** Setup github release with Apple Notarized builds.

### From Source

**NOTE: Building from source might be a bit rough around the edges, the xcode project/workspace is configured with my Apple Developer ID.**

```bash
git clone https://github.com/withakay/altswitch.git
cd altswitch
open altswitch.xcworkspace
```

Build and run the `AltSwitch` scheme in Xcode.

### Prerequisites

AltSwitch requires accessibility permissions to discover and switch between windows. The app will prompt you to grant these permissions on first launch. If code signing is not configured you might have to manually grant accessibility permissions for every build.

## Usage

### Basic Usage

1. Press your configured hotkey (default: `⌥ Option + Tab`)
2. Type to fuzzy search through open windows
3. Press `Enter` to switch to the selected window
4. Or use `Tab`/`Shift+Tab` to navigate through the list

### Keyboard Shortcuts

- `⌥ Option + Tab` - Show AltSwitch window
- `Tab` / `Shift + Tab` - Navigate through window list
- `↑` / `↓` - Navigate through window list
- `Enter` - Switch to selected window
- `Escape` - Dismiss AltSwitch
- `⌘ Command + ,` - Open preferences

### Fuzzy Search

Type any part of a window title or application name:

- "chr" matches "Google Chrome"
- "term" matches "Terminal"
- "xco" matches "Xcode"

The search is case-insensitive and matches anywhere in the string.

## Architecture

AltSwitch is built with a modular architecture using Swift packages:

### Core Packages

- **MacWindowDiscovery** - Window enumeration and discovery
- **MacWindowSwitch** - Window activation and switching logic
- **AltSwitch** - Main application with UI and user-facing features

### Key Components

- **Window Discovery Engine** - Reasonably fast window enumeration with caching
- **Fuzzy Search Service** - Intelligent(ish) fuzzy matching algorithm
- **Hotkey Manager** - Global hotkey handling
- **Settings Manager** - Configuration persistence to ~/.config/altswitch/settings.yaml
- **App Switcher** - Window activation and focus management

## Development

### Project Structure

```
altswitch/
├── altswitch-macos/         # Main macOS application
│   ├── AltSwitch/           # Main app source code
│   ├── AltSwitchTests/      # Unit and integration tests
│   └── AltSwitchUITests/    # UI automation tests
├── packages/                # Swift packages
│   ├── MacWindowDiscovery/  # Window discovery engine
│   └── MacWindowSwitch/     # Window switching logic
├── docs/                    # Documentation
└── scripts/                 # Build and development scripts
```

### Building

**TODO: Improve and document building via Makefile**

```bash
# Open in Xcode
open altswitch.xcworkspace

# Or build from command line
xcodebuild -workspace altswitch.xcworkspace -scheme AltSwitch -configuration Debug
```

### Running Tests

**TODO: Improve and document running tests via Makefile**

```bash
# Run all tests
xcodebuild test -workspace altswitch.xcworkspace -scheme AltSwitch

# Run specific test suite
xcodebuild test -workspace altswitch.xcworkspace -scheme AltSwitch -only-testing:AltSwitchTests/Unit
```

## Configuration

AltSwitch can be configured via the UI, from the menu bar icon select preferences.
AltSwitch stores configuration in `~/.config/AltSwitch/settings.yaml` for easy backup.
You can customize:

- Hotkey combinations
- ~Window appearance (size, colors, opacity)~ (Not yet implemented)
- Window filtering options



## Acknowledgments

AltSwitch builds upon the excellent work of:

- **AltTab** - https://github.com/lwouis/alt-tab-macos
- **Yabai** - https://github.com/koekeishiya/yabai
- **Rofi** - https://github.com/davatorium/rofi

## License

This project is licensed under the GNU GENERAL PUBLIC License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Before making a Pull Request. Please open an issue first to discuss what you would like to change.

## Support

If you encounter any issues or have questions:

1. Check the [issues page](https://github.com/withakay/altswitch/issues)
2. Review the [documentation](docs/)
3. Create a new issue with detailed information

---

**AltSwitch** - Switch smarter, not harder.
