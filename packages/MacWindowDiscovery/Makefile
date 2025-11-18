# Makefile for MacWindowDiscovery Swift Package
# Provides build, test, lint, and development workflow targets

# Project Configuration
PROJECT_NAME = MacWindowDiscovery
LIBRARY_TARGET = MacWindowDiscovery
CLI_TARGET = MacWindowDiscoveryCLI
CLI_EXECUTABLE = mac-window-discovery
DEBUG_APP_TARGET = MacWindowDiscoveryDebug
DEBUG_APP_EXECUTABLE = mac-window-discovery-debug
TEST_TARGET = MacWindowDiscoveryTests

# Build Configuration
CONFIGURATION_DEBUG = debug
CONFIGURATION_RELEASE = release
BUILD_DIR = .build
PRODUCTS_DIR = $(BUILD_DIR)/debug
RELEASE_PRODUCTS_DIR = $(BUILD_DIR)/release

# CLI Binary Paths
DEBUG_CLI = $(PRODUCTS_DIR)/$(CLI_EXECUTABLE)
RELEASE_CLI = $(RELEASE_PRODUCTS_DIR)/$(CLI_EXECUTABLE)

# Debug App Binary Paths
DEBUG_APP = $(PRODUCTS_DIR)/$(DEBUG_APP_EXECUTABLE)
RELEASE_APP = $(RELEASE_PRODUCTS_DIR)/$(DEBUG_APP_EXECUTABLE)

# Tools
SWIFT = swift
SWIFTFORMAT = swift-format
SWIFTLINT = swiftlint

# Version Scripts
VERSION_FILE = Version.json
SCRIPT_DIR = scripts
INCREMENT_BUILD = $(SCRIPT_DIR)/increment-build.sh
INCREMENT_VERSION = $(SCRIPT_DIR)/increment-version.sh
GENERATE_VERSION = $(SCRIPT_DIR)/generate-version.sh

# Default target
.DEFAULT_GOAL := help

# PHONY targets (not actual files)
.PHONY: help clean build build-debug build-release test test-verbose \
        run run-release install format lint check-format check-lint \
        run-debug-app run-debug-app-release \
        setup deps check-deps check-tools bootstrap resolve \
        dev ci quick release info debug-vars \
        version-info generate-version increment-build increment-version \
        bump-major bump-minor bump-patch

##@ Development Commands

help: ## Display this help message
	@echo "MacWindowDiscovery Development Makefile"
	@echo "======================================="
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build Targets

build: build-debug ## Build debug version (default)

build-debug: check-tools increment-build generate-version ## Build debug version of library and CLI
	@echo "🔨 Building $(PROJECT_NAME) (Debug)..."
	$(SWIFT) build -c $(CONFIGURATION_DEBUG)
	@echo "✅ Debug build completed: $(DEBUG_CLI)"

build-release: check-tools increment-version increment-build generate-version ## Build release version optimized for performance
	@echo "🔨 Building $(PROJECT_NAME) (Release)..."
	$(SWIFT) build -c $(CONFIGURATION_RELEASE)
	@echo "✅ Release build completed: $(RELEASE_CLI)"

resolve: check-tools ## Resolve package dependencies
	@echo "📦 Resolving package dependencies..."
	$(SWIFT) package resolve
	@echo "✅ Dependencies resolved"

update: check-tools ## Update package dependencies
	@echo "📦 Updating package dependencies..."
	$(SWIFT) package update
	@echo "✅ Dependencies updated"

##@ Test Targets

test: check-tools ## Run all tests
	@echo "🧪 Running tests..."
	$(SWIFT) test
	@echo "✅ Tests completed"

test-verbose: check-tools ## Run tests with verbose output
	@echo "🧪 Running tests (verbose)..."
	$(SWIFT) test --verbose

test-parallel: check-tools ## Run tests in parallel
	@echo "🧪 Running tests in parallel..."
	$(SWIFT) test --parallel
	@echo "✅ Parallel tests completed"

test-filter: check-tools ## Run specific test (usage: make test-filter FILTER=TestName)
	@echo "🧪 Running filtered tests..."
	$(SWIFT) test --filter $(FILTER)

##@ Run Targets

run: build-release ## Build and run CLI (uses release mode, compact format default)
	@echo "🚀 Running $(CLI_EXECUTABLE) list (Release)..."
	$(RELEASE_CLI) list

run-debug: build-debug ## Build debug version (note: ArgumentParser has a known issue in debug mode)
	@echo "⚠️  Note: Debug build may fail due to ArgumentParser availability check"
	@echo "🚀 Running $(CLI_EXECUTABLE) (Debug)..."
	$(DEBUG_CLI)

run-release: build-release ## Build and run CLI in release mode
	@echo "🚀 Running $(CLI_EXECUTABLE) (Release)..."
	$(RELEASE_CLI)

run-list: build-release ## Build and run CLI with 'list' command
	@echo "🚀 Running $(CLI_EXECUTABLE) list..."
	$(RELEASE_CLI) list

run-watch: build-release ## Build and run CLI with 'watch' command
	@echo "🚀 Running $(CLI_EXECUTABLE) watch..."
	$(RELEASE_CLI) watch

install: build-release ## Install CLI to /usr/local/bin
	@echo "📱 Installing $(CLI_EXECUTABLE) to /usr/local/bin..."
	@mkdir -p /usr/local/bin
	@cp $(RELEASE_CLI) /usr/local/bin/$(CLI_EXECUTABLE)
	@echo "✅ $(CLI_EXECUTABLE) installed"

uninstall: ## Remove CLI from /usr/local/bin
	@echo "🗑️  Uninstalling $(CLI_EXECUTABLE)..."
	@rm -f /usr/local/bin/$(CLI_EXECUTABLE)
	@echo "✅ $(CLI_EXECUTABLE) uninstalled"

run-debug-app: ## Build and run debug GUI app (uses swift run)
	@echo "🚀 Running $(DEBUG_APP_EXECUTABLE)..."
	$(SWIFT) run $(DEBUG_APP_EXECUTABLE)

run-debug-app-release: build-release ## Run debug app from built release binary
	@echo "🚀 Running $(DEBUG_APP_EXECUTABLE) (Release)..."
	@open $(RELEASE_APP)

##@ Code Quality

format: check-swift-format ## Format Swift code
	@echo "🎨 Formatting Swift code..."
	@if command -v $(SWIFTFORMAT) >/dev/null 2>&1; then \
		find Sources Tests -name "*.swift" | \
		xargs $(SWIFTFORMAT) format -i --parallel; \
		echo "✅ Swift code formatted"; \
	else \
		echo "❌ $(SWIFTFORMAT) not found. Install with: brew install swift-format"; \
		exit 1; \
	fi

check-format: check-swift-format ## Check Swift code formatting without modifying files
	@echo "🔍 Checking Swift code format..."
	@if command -v $(SWIFTFORMAT) >/dev/null 2>&1; then \
		find Sources Tests -name "*.swift" | \
		xargs $(SWIFTFORMAT) format --parallel; \
		echo "✅ Format check completed"; \
	else \
		echo "❌ $(SWIFTFORMAT) not found. Install with: brew install swift-format"; \
		exit 1; \
	fi

lint: check-swiftlint ## Lint Swift code
	@echo "🔍 Linting Swift code..."
	@if command -v $(SWIFTLINT) >/dev/null 2>&1; then \
		$(SWIFTLINT) lint; \
		echo "✅ Swift code linted"; \
	else \
		echo "❌ $(SWIFTLINT) not found. Install with: brew install swiftlint"; \
		exit 1; \
	fi

check-lint: check-swiftlint ## Check linting issues without fixing
	@echo "🔍 Checking Swift code style..."
	@if command -v $(SWIFTLINT) >/dev/null 2>&1; then \
		$(SWIFTLINT) lint --strict; \
	else \
		echo "❌ $(SWIFTLINT) not found. Install with: brew install swiftlint"; \
		exit 1; \
	fi

lint-fix: check-swiftlint ## Auto-fix linting issues where possible
	@echo "🔧 Auto-fixing lint issues..."
	@if command -v $(SWIFTLINT) >/dev/null 2>&1; then \
		$(SWIFTLINT) --fix; \
		echo "✅ Lint issues fixed"; \
	else \
		echo "❌ $(SWIFTLINT) not found. Install with: brew install swiftlint"; \
		exit 1; \
	fi

##@ Project Management

setup: deps bootstrap ## Complete project setup
	@echo "✅ Project setup completed"

deps: check-deps ## Install development dependencies
	@echo "📦 Installing development dependencies..."
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "❌ Homebrew not found. Please install: https://brew.sh"; \
		exit 1; \
	fi
	@echo "Installing swift-format..."
	@brew list swift-format >/dev/null 2>&1 || brew install swift-format
	@echo "Installing swiftlint..."
	@brew list swiftlint >/dev/null 2>&1 || brew install swiftlint
	@echo "✅ Dependencies installed"

bootstrap: check-tools resolve ## Bootstrap project (resolve packages, prepare build)
	@echo "🔧 Bootstrapping project..."
	@mkdir -p $(BUILD_DIR)
	@echo "✅ Project bootstrapped"

clean: ## Clean build artifacts
	@echo "🧹 Cleaning build artifacts..."
	$(SWIFT) package clean
	@echo "✅ Clean completed"

clean-deep: clean ## Deep clean including package cache
	@echo "🧹 Deep cleaning..."
	rm -rf $(BUILD_DIR)
	rm -rf .swiftpm
	@echo "✅ Deep clean completed"

reset: clean-deep resolve ## Reset project state (deep clean + resolve)
	@echo "🔄 Project reset completed"

##@ Utility Targets

check-tools: ## Verify required development tools
	@echo "🔧 Checking development tools..."
	@command -v $(SWIFT) >/dev/null 2>&1 || { echo "❌ swift not found"; exit 1; }
	@echo "✅ Development tools verified"

check-deps: ## Check for optional dependencies
	@echo "🔧 Checking optional dependencies..."
	@if ! command -v brew >/dev/null 2>&1; then \
		echo "⚠️  Homebrew not found (recommended for dependency management)"; \
	fi

check-swift-format: ## Check if swift-format is available
	@command -v $(SWIFTFORMAT) >/dev/null 2>&1 || { echo "⚠️  $(SWIFTFORMAT) not found. Install with: brew install swift-format"; }

check-swiftlint: ## Check if swiftlint is available
	@command -v $(SWIFTLINT) >/dev/null 2>&1 || { echo "⚠️  $(SWIFTLINT) not found. Install with: brew install swiftlint"; }

info: ## Display project information
	@echo "MacWindowDiscovery Project Information"
	@echo "======================================"
	@echo "Project: $(PROJECT_NAME)"
	@echo "Library Target: $(LIBRARY_TARGET)"
	@echo "CLI Target: $(CLI_TARGET)"
	@echo "CLI Executable: $(CLI_EXECUTABLE)"
	@echo "Test Target: $(TEST_TARGET)"
	@echo ""
	@echo "Build Directory: $(BUILD_DIR)"
	@echo ""
	@echo "Configurations:"
	@echo "  Debug: $(CONFIGURATION_DEBUG)"
	@echo "  Release: $(CONFIGURATION_RELEASE)"
	@echo ""
	@echo "CLI Binaries:"
	@echo "  Debug: $(DEBUG_CLI)"
	@echo "  Release: $(RELEASE_CLI)"
	@echo ""
	@echo "Swift Version: $$(swift --version | head -n 1)"

##@ Quick Development Workflow

dev: clean build-debug test ## Clean, build debug, and run tests
	@echo "🚀 Development build and test completed"

ci: clean build-release test lint ## Full CI pipeline (clean, build, test, lint)
	@echo "🎯 CI pipeline completed successfully"

quick: build-debug ## Quick build for development
	@echo "⚡ Quick build completed"

release: clean build-release test ## Prepare release build with full testing
	@echo "🎉 Release build completed and tested"

verify: check-format check-lint test ## Verify code quality and tests
	@echo "✅ Code verification completed"

##@ Package Management

show-dependencies: ## Show package dependencies
	@echo "📦 Package dependencies:"
	$(SWIFT) package show-dependencies

describe: ## Describe package
	@echo "📋 Package description:"
	$(SWIFT) package describe

dump-package: ## Dump Package.swift as JSON
	@echo "📄 Package manifest (JSON):"
	$(SWIFT) package dump-package

##@ Documentation

docs: ## Generate Swift documentation
	@echo "📚 Generating documentation..."
	$(SWIFT) package generate-documentation
	@echo "✅ Documentation generated"

docs-preview: ## Generate and preview documentation
	@echo "📚 Generating and previewing documentation..."
	$(SWIFT) package --disable-sandbox preview-documentation

##@ Version Management

version-info: ## Display current version and build number
	@echo "📊 Version Information:"
	@if [ -f "$(VERSION_FILE)" ]; then \
		version=$$(grep -o '"version":[[:space:]]*"[^"]*"' $(VERSION_FILE) | grep -o '[0-9]*\.[0-9]*\.[0-9]*'); \
		build=$$(grep -o '"build":[[:space:]]*[0-9]*' $(VERSION_FILE) | grep -o '[0-9]*'); \
		echo "  Version: $$version"; \
		echo "  Build: $$build"; \
		echo "  Full: $$version ($$build)"; \
	else \
		echo "  ❌ $(VERSION_FILE) not found"; \
	fi

generate-version: ## Generate Version.swift from Version.json
	@$(GENERATE_VERSION)

increment-build: ## Increment build number
	@$(INCREMENT_BUILD)

increment-version: ## Increment patch version (for release builds)
	@$(INCREMENT_VERSION) patch

bump-patch: generate-version ## Manually increment patch version
	@$(INCREMENT_VERSION) patch
	@$(GENERATE_VERSION)
	@make version-info

bump-minor: generate-version ## Manually increment minor version
	@$(INCREMENT_VERSION) minor
	@$(GENERATE_VERSION)
	@make version-info

bump-major: generate-version ## Manually increment major version
	@$(INCREMENT_VERSION) major
	@$(GENERATE_VERSION)
	@make version-info

# Debug target to show variables
debug-vars: ## Show Makefile variables (for debugging)
	@echo "Debug Variables:"
	@echo "PROJECT_NAME = $(PROJECT_NAME)"
	@echo "LIBRARY_TARGET = $(LIBRARY_TARGET)"
	@echo "CLI_TARGET = $(CLI_TARGET)"
	@echo "CLI_EXECUTABLE = $(CLI_EXECUTABLE)"
	@echo "BUILD_DIR = $(BUILD_DIR)"
	@echo "DEBUG_CLI = $(DEBUG_CLI)"
	@echo "RELEASE_CLI = $(RELEASE_CLI)"
	@echo "SWIFT = $(SWIFT)"
	@echo "VERSION_FILE = $(VERSION_FILE)"
