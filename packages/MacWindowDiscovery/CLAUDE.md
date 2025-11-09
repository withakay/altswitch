# MacWindowDiscovery Development Guide

## Project Overview

MacWindowDiscovery is a Swift package that provides robust window discovery and monitoring capabilities for macOS applications. It combines multiple macOS APIs (Accessibility, Core Graphics, NSWorkspace) to reliably discover and track windows across the system.

### Key Features

- **Multi-API Window Discovery**: Combines AX (Accessibility), CG (Core Graphics), and NSWorkspace APIs for comprehensive window detection
- **Smart Caching**: Built-in caching layer with invalidation strategies to minimize API calls
- **Real-time Monitoring**: Event-driven window change detection using NSWorkspace notifications
- **Space-Aware**: Tracks windows across multiple macOS Spaces
- **CLI Tool**: Includes a command-line interface for testing and debugging
- **Zero External Dependencies**: Core library has no external dependencies (CLI uses ArgumentParser)

### Architecture

The package is organized into several key components:

- **Core**: Data models and error types (`WindowInfo`, `WindowDiscoveryOptions`, `WindowDiscoveryError`)
- **Discovery**: Window discovery engine and filtering logic
- **Caching**: Performance-optimized caching layer with event monitoring
- **Providers**: Platform-specific implementations (AX, CG, NSWorkspace)
- **CLI**: Command-line tool for testing and debugging

## Swift Version

This project uses **Swift 6.2** with the following requirements:

- Minimum macOS version: 13.0 (Ventura)
- Swift tools version: 6.0+
- Leverages Swift Concurrency (async/await)
- Uses modern Swift 6 features including strict concurrency checking

## Source Control

This project uses **Jujutsu (jj)** for version control, which provides a modern alternative to Git with:

- Automatic local commits on every change
- First-class support for evolving changes
- Simplified rebasing and conflict resolution
- Git compatibility (works with Git remotes)

### Common jj Commands

```bash
# View current status
jj status

# Create a new change
jj new

# Describe current change (commit message)
jj describe

# View log
jj log

# Push to remote
jj git push

# Pull from remote
jj git fetch

# Squash changes
jj squash
```

## Building the Project

### Quick Start

```bash
# Install dependencies
make setup

# Build debug version
make build

# Run tests
make test

# Build and run CLI
make run
```

### Available Make Targets

#### Build Targets
- `make build` - Build debug version (default)
- `make build-debug` - Build debug version
- `make build-release` - Build release version with optimizations
- `make resolve` - Resolve package dependencies
- `make update` - Update package dependencies

#### Test Targets
- `make test` - Run all tests
- `make test-verbose` - Run tests with verbose output
- `make test-parallel` - Run tests in parallel
- `make test-filter FILTER=TestName` - Run specific test

#### Run Targets
- `make run` - Build and run CLI
- `make run-release` - Build and run release CLI
- `make run-list` - Run CLI with 'list' command
- `make run-watch` - Run CLI with 'watch' command
- `make install` - Install CLI to /usr/local/bin
- `make uninstall` - Remove CLI from /usr/local/bin

#### Code Quality
- `make format` - Format Swift code with swift-format
- `make check-format` - Check formatting without modifying
- `make lint` - Lint Swift code with swiftlint
- `make check-lint` - Check linting issues
- `make lint-fix` - Auto-fix linting issues

#### Project Management
- `make setup` - Complete project setup (deps + bootstrap)
- `make deps` - Install development dependencies
- `make bootstrap` - Bootstrap project (resolve + prepare)
- `make clean` - Clean build artifacts
- `make clean-deep` - Deep clean including package cache
- `make reset` - Reset project state (deep clean + resolve)

#### Development Workflows
- `make dev` - Clean, build debug, and run tests
- `make ci` - Full CI pipeline (clean, build, test, lint)
- `make quick` - Quick build for development
- `make release` - Prepare release build with testing
- `make verify` - Verify code quality and tests

#### Information
- `make info` - Display project information
- `make show-dependencies` - Show package dependencies
- `make describe` - Describe package
- `make help` - Display all available targets

### Manual Swift Package Manager Commands

If you prefer to use Swift Package Manager directly:

```bash
# Build
swift build

# Build release
swift build -c release

# Run tests
swift test

# Run CLI
swift run mac-window-discovery

# Run specific CLI command
swift run mac-window-discovery list
swift run mac-window-discovery watch

# Generate documentation
swift package generate-documentation

# Show dependencies
swift package show-dependencies
```

## Development Workflow

### Typical Development Cycle

1. **Create a new change**: `jj new`
2. **Make code changes**
3. **Build and test**: `make dev`
4. **Format and lint**: `make format && make lint`
5. **Verify**: `make verify`
6. **Describe change**: `jj describe`
7. **Push**: `jj git push`

### Before Committing

Always run these commands before committing:

```bash
# Verify everything is good
make verify

# Or run the full CI pipeline
make ci
```

## Testing

The project includes comprehensive test coverage:

- **Unit Tests**: Test individual components in isolation with mocks
- **Integration Tests**: Test full window discovery workflows
- **CLI Tests**: Manual testing scripts for the command-line tool

### Running Tests

```bash
# Run all tests
make test

# Run with verbose output
make test-verbose

# Run specific test
make test-filter FILTER=WindowCacheTests

# Run tests in parallel
make test-parallel
```

### Test Organization

- `Tests/MacWindowDiscoveryTests/Unit/` - Unit tests with mocks
- `Tests/MacWindowDiscoveryTests/Integration/` - Integration tests
- `Tests/MacWindowDiscoveryTests/Mocks/` - Mock providers for testing

## Code Quality Standards

### Formatting

This project uses `swift-format` for consistent code formatting:

```bash
# Format code
make format

# Check format without modifying
make check-format
```

### Linting

SwiftLint is used to enforce coding standards:

```bash
# Run linter
make lint

# Check linting issues
make check-lint

# Auto-fix issues
make lint-fix
```

### Code Style Guidelines

- Use meaningful variable and function names
- Add documentation comments for public APIs
- Keep functions focused and single-purpose
- Prefer composition over inheritance
- Use Swift Concurrency (async/await) for asynchronous operations
- Handle errors explicitly with proper error types

## Permissions

The window discovery functionality requires specific macOS permissions:

### Accessibility Permission

Required for AX (Accessibility) API access to get window titles and properties.

**Grant via CLI**:
```bash
swift run mac-window-discovery permissions
```

**Grant manually**: System Settings → Privacy & Security → Accessibility

### Screen Recording Permission

Required for some CG (Core Graphics) window list operations.

**Grant manually**: System Settings → Privacy & Security → Screen Recording

## CLI Usage

The package includes a command-line tool for testing and debugging:

```bash
# List all windows
mac-window-discovery list

# List windows for specific app
mac-window-discovery app Safari

# Watch for window changes
mac-window-discovery watch

# Check permissions
mac-window-discovery permissions

# Get help
mac-window-discovery --help
```

## Project Structure

```
MacWindowDiscovery/
├── Sources/
│   ├── MacWindowDiscovery/          # Core library
│   │   ├── Core/                    # Data models and errors
│   │   ├── Discovery/               # Window discovery engine
│   │   ├── Caching/                 # Caching and monitoring
│   │   ├── Providers/               # Platform-specific providers
│   │   ├── Protocols/               # Abstraction protocols
│   │   ├── Platform/                # Platform APIs (Spaces)
│   │   └── Extensions/              # Swift extensions
│   └── MacWindowDiscoveryCLI/       # CLI tool
├── Tests/
│   └── MacWindowDiscoveryTests/
│       ├── Unit/                    # Unit tests
│       ├── Integration/             # Integration tests
│       └── Mocks/                   # Mock providers
├── Package.swift                    # SPM manifest
├── Makefile                        # Build automation
├── CLAUDE.md                       # This file
├── AGENTS.md                       # AI agent instructions
└── README.md                       # User documentation
```

## Troubleshooting

### Build Issues

```bash
# Clean and rebuild
make clean
make build

# Deep clean if issues persist
make clean-deep
make setup
```

### Test Failures

- Ensure you have granted Accessibility permissions
- Some integration tests require a graphical session (don't run via SSH)
- Check that you have windows open for integration tests to discover

### Permission Issues

- Run `swift run mac-window-discovery permissions` to check status
- Grant required permissions in System Settings
- Restart the Terminal app after granting permissions

### ArgumentParser Debug Mode Issue

**Known Issue**: The CLI has a known issue with ArgumentParser's debug mode availability check. Debug builds may fail with an error about missing availability annotations, even though the annotations are present.

**Workaround**: Use release builds for running the CLI:
```bash
# Use make run (which uses release mode by default)
make run

# Or build release explicitly
make build-release
.build/release/mac-window-discovery list

# Or use swift run with release configuration
swift run -c release mac-window-discovery list
```

The issue is in ArgumentParser's DEBUG-mode validation and does not affect release builds or functionality.

## Performance Considerations

- The caching layer significantly reduces API overhead
- Cache TTL is configurable (default: 100ms)
- Event monitoring keeps cache in sync with window changes
- Use `WindowDiscoveryOptions` to customize behavior for your use case

## Contributing

When contributing to this project:

1. Use jj for version control
2. Follow Swift 6.2 best practices
3. Write tests for new functionality
4. Run `make verify` before committing
5. Add documentation for public APIs
6. Update relevant documentation files

## Resources

- [Swift Package Manager Documentation](https://swift.org/package-manager/)
- [Jujutsu Documentation](https://martinvonz.github.io/jj/)
- [macOS Accessibility API](https://developer.apple.com/documentation/applicationservices/axuielement)
- [Core Graphics Window Services](https://developer.apple.com/documentation/coregraphics/quartz_window_services)
