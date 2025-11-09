# MacWindowDiscovery - AI Agent Instructions

This document provides instructions for AI agents (like Claude Code, Cursor, etc.) working on the MacWindowDiscovery project.

## Project Overview

MacWindowDiscovery is a Swift 6.2 package providing window discovery and monitoring for macOS applications. It's a library with a CLI tool, built using Swift Package Manager.

**Key Facts:**
- **Language**: Swift 6.2
- **Platform**: macOS 13.0+
- **Build System**: Swift Package Manager (SPM)
- **Source Control**: Jujutsu (jj) - Git compatible
- **Package Type**: Library + Executable (CLI)
- **Dependencies**: Zero for core library, ArgumentParser for CLI only

## Building and Testing

### Always Use Make

This project uses a Makefile for all build operations. **Always prefer Make targets over direct Swift commands.**

**IMPORTANT**: Due to an ArgumentParser debug mode issue, the CLI must be run in release mode. The Makefile handles this automatically with `make run`.

#### Quick Reference

```bash
# Build debug version
make build

# Run tests
make test

# Build and test
make dev

# Run CLI (uses release mode due to ArgumentParser issue)
make run

# Format and lint
make format
make lint

# Full verification before commit
make verify

# CI pipeline
make ci
```

#### Essential Make Targets

- `make build` - Build debug version
- `make build-release` - Build optimized release version
- `make test` - Run all tests
- `make test-verbose` - Run tests with detailed output
- `make run` - Build and run the CLI
- `make format` - Format code with swift-format
- `make lint` - Lint code with swiftlint
- `make verify` - Run format check, lint, and tests
- `make dev` - Clean, build, and test (typical dev workflow)
- `make ci` - Full CI pipeline (clean, build, test, lint)
- `make clean` - Clean build artifacts
- `make help` - Show all available targets

### Before Committing Code

**Always run** before committing:
```bash
make verify
```

Or for thorough checking:
```bash
make ci
```

## Project Structure

```
MacWindowDiscovery/
├── Sources/
│   ├── MacWindowDiscovery/          # Core library (public API)
│   │   ├── Core/                    # Models and errors
│   │   │   ├── WindowInfo.swift
│   │   │   ├── WindowDiscoveryOptions.swift
│   │   │   └── WindowDiscoveryError.swift
│   │   ├── Discovery/               # Main discovery logic
│   │   │   ├── WindowDiscoveryEngine.swift
│   │   │   ├── WindowFilterPolicy.swift
│   │   │   ├── WindowInfoBuilder.swift
│   │   │   └── WindowValidator.swift
│   │   ├── Caching/                 # Performance caching
│   │   │   ├── CachedWindowDiscoveryEngine.swift
│   │   │   ├── WindowCache.swift
│   │   │   ├── WindowEventMonitor.swift
│   │   │   ├── CacheKey.swift
│   │   │   └── CacheEntry.swift
│   │   ├── Providers/               # Platform implementations
│   │   │   ├── CGWindowProvider.swift
│   │   │   ├── AXWindowProvider.swift
│   │   │   └── NSWorkspaceProvider.swift
│   │   ├── Protocols/               # Abstractions
│   │   │   ├── WindowProviderProtocol.swift
│   │   │   ├── AXWindowProviderProtocol.swift
│   │   │   └── WorkspaceProviderProtocol.swift
│   │   ├── Platform/                # Platform-specific APIs
│   │   │   └── SpacesAPI.swift
│   │   └── Extensions/
│   │       └── Array+WindowInfo.swift
│   └── MacWindowDiscoveryCLI/       # CLI tool
│       ├── main.swift
│       ├── ListCommand.swift
│       ├── WatchCommand.swift
│       ├── AppCommand.swift
│       ├── PermissionsCommand.swift
│       └── OutputFormatter.swift
├── Tests/
│   └── MacWindowDiscoveryTests/
│       ├── Unit/                    # Unit tests (with mocks)
│       ├── Integration/             # Integration tests (real APIs)
│       └── Mocks/                   # Mock implementations
├── Package.swift                    # SPM manifest
└── Makefile                        # Build automation
```

## Swift Version and Language Features

**Swift Version**: 6.2
**Swift Tools Version**: 6.0+
**Platform**: macOS 13.0+

### Language Features in Use

- **Swift Concurrency**: Uses `async`/`await` throughout
- **Strict Concurrency Checking**: Enabled
- **Modern Error Handling**: Typed errors with `WindowDiscoveryError`
- **Actor Isolation**: Used for thread-safe caching
- **Sendable Conformance**: Required for concurrent code
- **Value Semantics**: Prefers structs over classes

### Coding Standards

1. **Follow existing patterns**: Match the style of surrounding code
2. **Use protocols for abstraction**: See `WindowProviderProtocol`, `AXWindowProviderProtocol`
3. **Prefer composition**: Mock-friendly design with dependency injection
4. **Document public APIs**: All public types, methods, and properties
5. **Handle errors explicitly**: Use `WindowDiscoveryError` for domain errors
6. **Write tests**: Unit tests for logic, integration tests for platform APIs

## Common Tasks

### Adding a New Feature

1. **Plan**: Understand where the feature fits in the architecture
2. **Core first**: Add to `Sources/MacWindowDiscovery/` if it's library functionality
3. **CLI second**: Add to `Sources/MacWindowDiscoveryCLI/` if it's a CLI command
4. **Test**: Add tests in `Tests/MacWindowDiscoveryTests/`
5. **Document**: Update public API documentation
6. **Verify**: Run `make verify`
7. **Commit**: Use jj to commit changes

### Modifying Existing Code

1. **Read tests first**: Understand expected behavior from tests
2. **Check protocols**: Many components use protocol-based design
3. **Update tests**: Modify or add tests for changes
4. **Run tests**: `make test` to ensure nothing breaks
5. **Format**: `make format` to apply consistent formatting
6. **Lint**: `make lint` to catch style issues

### Adding Dependencies

**IMPORTANT**: The core library has ZERO external dependencies. This is intentional.

- **For core library**: Do NOT add external dependencies
- **For CLI tool**: Dependencies are acceptable if needed (e.g., ArgumentParser)

To add a CLI-only dependency:
1. Edit `Package.swift`
2. Add to `dependencies` array
3. Add to `MacWindowDiscoveryCLI` target's dependencies
4. Run `make resolve`
5. Test with `make build && make test`

### Working with Platform APIs

The project wraps three macOS APIs:

1. **Core Graphics (CG)**: `CGWindowProvider` - Fast window list via window server
2. **Accessibility (AX)**: `AXWindowProvider` - Detailed window info via accessibility
3. **Workspace**: `NSWorkspaceProvider` - App metadata via NSWorkspace

**Testing Platform APIs**:
- Unit tests use mocks (`MockWindowProvider`, `MockAXProvider`, `MockWorkspaceProvider`)
- Integration tests use real APIs (require permissions)
- Run integration tests: `make test` (they're included by default)

## Source Control with Jujutsu (jj)

This project uses **jj** (Jujutsu), not git directly. jj is Git-compatible but provides a better workflow.

### Essential jj Commands

```bash
# View status
jj status

# Create a new change (like git commit, but creates empty commit)
jj new

# Add a description to current change
jj describe

# View history
jj log

# Push to remote (jj uses Git remotes)
jj git push

# Pull from remote
jj git fetch

# Squash current change into parent
jj squash

# Abandon a change
jj abandon
```

### jj vs Git Mental Model

- **jj automatically commits**: Every change is automatically captured
- **Changes are mutable**: You can edit history easily
- **jj new**: Creates a new change on top of current
- **jj describe**: Like `git commit --amend` but cleaner
- **jj squash**: Combines changes (like interactive rebase)

### When Committing

1. Make your changes
2. Run `make verify` or `make ci`
3. Use `jj describe` to write a good commit message
4. Use `jj git push` to push to remote

## Testing Strategy

### Test Types

1. **Unit Tests** (`Tests/.../Unit/`)
   - Test individual components in isolation
   - Use mocks for external dependencies
   - Fast and deterministic

2. **Integration Tests** (`Tests/.../Integration/`)
   - Test full workflows with real APIs
   - Require macOS permissions
   - May require active windows

3. **Manual CLI Tests**
   - Use `make run-list`, `make run-watch`
   - Test permissions flow
   - Verify output formatting

### Running Tests

```bash
# All tests
make test

# Verbose output
make test-verbose

# Specific test
make test-filter FILTER=WindowCacheTests

# Parallel execution
make test-parallel
```

### Test Requirements

- Integration tests need Accessibility permission
- Some tests require a graphical session (don't run via SSH)
- Tests expect at least some windows to be open

## Permissions and Entitlements

The project requires macOS permissions for full functionality:

### Accessibility Permission
- **Required for**: AX API (window titles, properties)
- **Grant via**: `swift run mac-window-discovery permissions`
- **Manual**: System Settings → Privacy & Security → Accessibility

### Screen Recording Permission
- **Required for**: Some CG operations
- **Grant via**: System Settings → Privacy & Security → Screen Recording

**For Agents**: Don't try to grant permissions programmatically. Instruct the user to run the permissions command.

## Performance Considerations

### Caching Layer

The `CachedWindowDiscoveryEngine` wraps `WindowDiscoveryEngine`:
- Caches window lists with TTL (default 100ms)
- Invalidates on NSWorkspace events
- Significantly reduces API overhead

**When to bypass cache**:
```swift
// Force fresh data
let options = WindowDiscoveryOptions(cacheTTL: 0)
```

### API Performance

- **CG API**: Fastest, but limited info
- **AX API**: Slower, but rich info
- **Combined approach**: CG for list, AX for details

## Code Review Checklist

When reviewing or submitting code:

- [ ] Follows existing architectural patterns
- [ ] Public APIs are documented
- [ ] Tests added/updated for changes
- [ ] No external dependencies added to core library
- [ ] Uses Swift Concurrency properly (actors, sendable)
- [ ] Error handling uses `WindowDiscoveryError`
- [ ] Runs `make verify` successfully
- [ ] Runs `make ci` successfully
- [ ] Commit message describes the "why"

## CLI Commands for Agents

### Building
```bash
make build              # Build debug
make build-release      # Build release
```

### Testing
```bash
make test              # Run tests
make test-verbose      # Verbose tests
```

### Code Quality
```bash
make format            # Format code
make lint              # Lint code
make verify            # Format + lint + test
```

### Development Workflow
```bash
make dev               # Clean + build + test
make ci                # Full CI pipeline
```

### Running CLI
```bash
make run               # Run CLI
make run-list          # Run 'list' command
make run-watch         # Run 'watch' command
```

### Project Info
```bash
make info              # Show project info
make help              # Show all targets
```

## Common Pitfalls for Agents

1. **Don't use `swift build` directly**: Use `make build` instead
2. **Don't run debug builds of the CLI**: Use `make run` (which uses release mode) due to an ArgumentParser debug validation issue
3. **Don't forget tests**: Always add/update tests for changes
4. **Don't add dependencies lightly**: Core library must stay dependency-free
5. **Don't skip verification**: Run `make verify` before completing work
6. **Don't use git commands**: Use `jj` commands instead
7. **Don't modify Package.swift without testing**: Always run `make resolve && make build` after changes
8. **Don't assume permissions**: Integration tests may fail without permissions

## Getting Help

- **Build issues**: Try `make clean && make build`
- **Test issues**: Ensure permissions are granted
- **Format issues**: Run `make format`
- **General help**: Run `make help` for all targets

## Resources

- **CLAUDE.md**: Detailed development guide for humans
- **README.md**: User-facing documentation
- **Package.swift**: Package manifest and configuration
- **Makefile**: Build automation (read for target details)
- **Tests/**: Example usage and expected behavior

## Summary

**Quick Start for Agents:**
1. Use `make build` to build
2. Use `make test` to test
3. Use `make verify` before committing
4. Use `jj` for source control
5. Follow existing patterns in the codebase
6. Document public APIs
7. Don't add external dependencies to core library
