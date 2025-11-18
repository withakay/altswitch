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

### From Release (Recommended)

Download the latest release from the [releases page](https://github.com/withakay/altswitch/releases):

1. Download either the DMG or ZIP file
2. **DMG**: Open and drag AltSwitch to Applications
3. **ZIP**: Unzip and drag AltSwitch.app to Applications
4. Launch AltSwitch from Applications
5. Grant required permissions when prompted

**All releases are code-signed and notarized by Apple.** You won't see any security warnings when installing.

### From Source

**NOTE: Building from source requires your own Apple Developer ID for code signing.**

```bash
git clone https://github.com/withakay/altswitch.git
cd altswitch/altswitch-macos
make build-release
```

The built app will be in `dist/AltSwitch.app`.

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

All build commands should be run from the `altswitch-macos/` directory:

```bash
# Build debug version
make build

# Build release version (auto-increments version, creates DMG/ZIP)
make build-release

# Quick build and run
make quick

# Clean build artifacts
make clean
```

### Running Tests

```bash
# Run all tests
make test

# Run only unit tests
make test-unit

# Run UI tests
make test-ui

# Run with verbose output
make test-verbose

# Generate coverage report
make coverage
```

### Version Management

```bash
# Check current version
make version-info

# Manually bump version
make bump-patch    # 0.5.0 → 0.5.1
make bump-minor    # 0.5.0 → 0.6.0
make bump-major    # 0.5.0 → 1.0.0
```

### Creating a Release

All releases are automatically **code-signed and notarized** by Apple.

#### Prerequisites for Notarization

Before creating releases, you need to set up notarization credentials:

1. **Apple Developer Account** with Developer ID certificate
2. **Install Developer ID Certificate** in Xcode:
   - Xcode → Settings → Accounts → Manage Certificates
   - Or download from: https://developer.apple.com/account/resources/certificates/list

3. **Configure Notarization Credentials**:
   ```bash
   # Generate an app-specific password at: https://appleid.apple.com/account/manage
   # Then store credentials:
   xcrun notarytool store-credentials "notarytool-altswitch" \
     --apple-id "your-apple-id@example.com" \
     --team-id "576985M4ZN" \
     --password "xxxx-xxxx-xxxx-xxxx"
   ```

#### Release Workflow

```bash
# Complete release workflow (build, notarize, package, create GitHub release)
make publish

# Or step by step:
make build-release      # Build, notarize, and create DMG/ZIP (takes 1-5 minutes)
make github-release     # Create GitHub release with assets
```

**Note**: `make build-release` automatically:
- Increments version
- Builds with code signing
- **Notarizes with Apple** (1-5 minutes)
- **Staples notarization ticket**
- Creates DMG and ZIP packages

### Development Workflow

```bash
# Quick development cycle
make dev              # Clean, build debug, run tests

# Full CI pipeline
make ci               # Clean, build release, test, analyze

# Code quality
make format           # Format Swift code
make lint             # Lint Swift code
```

### Available Make Targets

Run `make help` to see all available targets with descriptions.

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
